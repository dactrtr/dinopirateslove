-- entities/player/projectile.lua
-- Plungerang projectile entity
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Projectile = Class('Projectile')

function Projectile:initialize(player, direction, world)
	-- Safety check
	if not player then error("Projectile requires a player reference") end
	if not world then error("Projectile requires a world reference") end

	-- Dimensions (Initialize first to avoid nil errors if used in position logic)
	self.width = 16
	self.height = 16

	self.player = player
	self.world = world
	
	-- Note: player.x and player.y are the CENTER of the player sprite (see Player:draw)
	-- So we don't need to add spriteWidth/2 or spriteHeight/2
	-- Position (center X, center Y + 15 pixels down)
	self.x = player.x
	self.y = player.y + 15
	
	-- Movement
	self.speed = 480 -- Pixels per second (8 pixels per frame at 60fps)
	self.direction = direction -- "left", "right", "up", "down"
	self.returning = false
	self.distanceTraveled = 0
	self.maxDistance = 100 -- Maximum travel distance before returning
	
	-- Velocity based on direction
	self.vx = 0
	self.vy = 0
	self:setVelocityFromDirection(direction)
	
	-- Animation (single spinning animation for all directions)
	self.spritesheet = love.graphics.newImage('assets/images/items/projectile-table-24-24.png')
	local grid = anim8.newGrid(24, 24, self.spritesheet:getWidth(), self.spritesheet:getHeight())
	
	-- Use all 4 frames as a spinning animation
	self.animation = anim8.newAnimation(grid('1-4', 1), 0.1)
	
	-- Add to BUMP world
	world:add(self, self.x - self.width/2, self.y - self.height/2, self.width, self.height)
	
	printDebug("🪃 Projectile created at (" .. self.x .. ", " .. self.y .. ") direction: " .. direction)
end

function Projectile:setVelocityFromDirection(direction)
	if direction == "right" then
		self.vx = self.speed
		self.vy = 0
	elseif direction == "left" then
		self.vx = -self.speed
		self.vy = 0
	elseif direction == "up" then
		self.vx = 0
		self.vy = -self.speed
	elseif direction == "down" then
		self.vx = 0
		self.vy = self.speed
	end
end

function Projectile:update(dt)
	-- Update animation
	self.animation:update(dt)
	
	if self.returning then
		-- Homing behavior: move toward player's current position
		local dx = self.player.x - self.x
		local dy = self.player.y - self.y
		local dist = math.sqrt(dx*dx + dy*dy)
		
		-- Check if caught by player
		if dist < 10 then
			self:onCaught()
			return
		end
		
		-- Normalize and apply speed
		local vx = (dx / dist) * self.speed
		local vy = (dy / dist) * self.speed
		
		self:move(vx * dt, vy * dt)
	else
		-- Linear movement in initial direction
		local moveX = self.vx * dt
		local moveY = self.vy * dt
		
		-- Track distance
		self.distanceTraveled = self.distanceTraveled + math.sqrt(moveX*moveX + moveY*moveY)
		
		-- Check if max distance reached
		if self.distanceTraveled >= self.maxDistance then
			self:startReturn()
		end
		
		self:move(moveX, moveY)
	end
end

function Projectile:move(dx, dy)
	-- Use BUMP for collision detection
	local actualX, actualY, cols, len = self.world:move(
		self, 
		self.x - self.width/2 + dx, 
		self.y - self.height/2 + dy,
		self.collisionFilter
	)
	
	-- Update center position from BUMP position (which is top-left)
	self.x = actualX + self.width/2
	self.y = actualY + self.height/2
	
	-- Handle collisions
	for i = 1, len do
		local col = cols[i]
		self:handleCollision(col.other, col)
	end
end

function Projectile:collisionFilter(item, other)
	-- Safety check
	if not other then return 'cross' end
	
	-- Ignore player during launch phase
	if not item.returning and other.class and other.class.name == "Player" then
		return 'cross'
	end
	
	-- Detect player during return phase (catch)
	if item.returning and other.class and other.class.name == "Player" then
		return 'touch'
	end
	
	-- Detect enemies
	if other.class and other.class.name == "Brocorat" then
		return 'touch'
	end
	
	-- Detect walls
	if other.isWall then
		return 'touch'
	end
	
	-- Detect props
	if other.class and other.class.name == "PropItem" then
		return 'touch'
	end
	
	-- Detect CrewMembers
	if other.class and other.class.name == "CrewMember" then
		return 'touch'
	end
	
	-- Cross everything else
	return 'cross'
end

function Projectile:handleCollision(other, col)
	-- Player catch (during return)
	if self.returning and other.class and other.class.name == "Player" then
		self:onCaught()
		return
	end
	
	-- Enemy hit
	if other.class and other.class.name == "Brocorat" then
		printDebug("🎯 Projectile hit enemy!")
		-- TODO: Stun/blind enemy
		if other.onHitByProjectile then
			other:onHitByProjectile()
		end
		self:startReturn()
		return
	end
	
	-- CrewMember hit - stun and lose projectile
	if other.class and other.class.name == "CrewMember" then
		printDebug("🎯 Projectile hit CrewMember - permanently stunned!")
		-- Permanently stun the crewmember
		if other.stunInfinite then
			other:stunInfinite()
		end
		-- Projectile is lost
		self.player.hasProjectile = false
		PlayerData.items.hasPlunger = false
		PlayerData.activeItem = 0
		self:destroy()
		return
	end
	
	-- Wall or Prop hit
	if other.isWall or (other.class and other.class.name == "PropItem") then
		printDebug("💥 Projectile hit wall/prop")
		self:startReturn()
		return
	end
end

function Projectile:startReturn()
	if not self.returning then
		self.returning = true
		printDebug("↩️ Projectile returning to player")
	end
end

function Projectile:onCaught()
	printDebug("✅ Projectile caught by player!")
	-- Reset player's plunging state
	if self.player then
		self.player.isPlunging = false
		self.player.projectile = nil
	end
	-- Remove projectile
	self:destroy()
end

function Projectile:destroy()
	if self.world and self.world:hasItem(self) then
		self.world:remove(self)
	end
	self.destroyed = true
end

function Projectile:draw()
	if self.destroyed then return end
	
	-- Draw animation centered on position
	self.animation:draw(
		self.spritesheet,
		self.x,
		self.y,
		0, -- rotation
		1, -- scaleX
		1, -- scaleY
		12, -- ox: origin X (center of 24px sprite)
		12  -- oy: origin Y (center of 24px sprite)
	)
end

function Projectile:drawDebug()
	if self.destroyed then return end
	
	-- Draw collision box
	local bumpX, bumpY = self.x - self.width/2, self.y - self.height/2
	love.graphics.setColor(1, 0, 1, 0.5) -- Magenta
	love.graphics.rectangle("fill", bumpX, bumpY, self.width, self.height)
	
	-- Draw center point
	love.graphics.setColor(1, 1, 0, 1) -- Yellow
	love.graphics.circle("fill", self.x, self.y, 2)
	
	love.graphics.setColor(1, 1, 1, 1) -- Reset
end

return Projectile
