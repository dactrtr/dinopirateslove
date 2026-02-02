-- Door.lua
-- Door entity for room transitions in Love2D

local Door = {}
Door.__index = Door
Door.name = "Door" -- Class name for identification

-- Convert LDTK direction to game direction
local function convertDirection(ldtkDir)
	local conversion = {
		n = "top",
		s = "down",
		w = "left",
		e = "right",
		["<"] = "left",
		[">"] = "right",
		["^"] = "top",
		["v"] = "down",
		-- Diagonal directions - map to primary direction
		ne = "top",    -- northeast -> top
		se = "down",   -- southeast -> down
		sw = "down",   -- southwest -> down
		nw = "top",     -- northwest -> top
		-- String names from DoorsConnection
		Top = "top",
		Down = "down",
		Left = "left",
		Right = "right"
	}
	
	local converted = conversion[ldtkDir]
	if not converted then
		print("⚠️ WARNING: Unknown door direction '" .. tostring(ldtkDir) .. "', defaulting to 'right'")
		return "right"  -- Safe fallback
	end
	
	return converted
end

function Door.new(x, y, w, h, direction, status, nextLevelIid, world, destinationRoomNumber)
	local self = setmetatable({}, Door)
	self.class = Door -- Reference to class for type checking
	
	-- Convert direction if needed
	self.direction = convertDirection(direction)
	self.status = status or "open"  -- "open" or "closed"
	self.nextLevelIid = nextLevelIid
	self.destinationRoomNumber = destinationRoomNumber
	
	-- Use provided positions and dimensions
	self.x = x
	self.y = y
	self.width = w or 16
	self.height = h or 16
	
	-- Add to BUMP world for collision detection
	self.world = world
	if world then
		world:add(self, self.x, self.y, self.width, self.height)
	end
	
	return self
end

function Door:isa(class)
	return class == Door
end

function Door:goTo()
	-- This will be called by the collision handler in Player
	-- The actual transition logic will be in gameScene
	print("🚪 Door transition to level: " .. tostring(self.nextLevelIid))
end

function Door:prevRoom(direction, playerX, playerY)
	-- Set spawn coordinates for the player when entering from this direction
	-- We increase the offsets to prevent immediate collision with the door
	PlayerData.lastRoom = direction
	
	local spawnCoordinates = {
		top = {x = playerX or 200, y = 185},    -- Entering FROM top (appear near bottom)
		down = {x = playerX or 200, y = 55},    -- Entering FROM bottom (appear near top)
		right = {x = 55, y = playerY or 120},   -- Entering FROM right (appear near left)
		left = {x = 345, y = playerY or 120}    -- Entering FROM left (appear near right)
	}
	
	-- Store in PlayerData (Global state)
	PlayerData.playerSpawn.x = spawnCoordinates[direction].x
	PlayerData.playerSpawn.y = spawnCoordinates[direction].y
	
	-- Store in self (Local reference)
	self.spawnX = PlayerData.playerSpawn.x
	self.spawnY = PlayerData.playerSpawn.y
	
	print("📍 Setting spawn for direction " .. direction .. ": (" .. self.spawnX .. ", " .. self.spawnY .. ")")
end

function Door:update(dt)
	-- Doors don't need update logic for now
end

function Door:draw()
	-- Optional: Draw debug rectangles for doors
	if DRAW_DEBUG_DOORS then
		love.graphics.setColor(0, 1, 0, 0.5) -- Green semi-transparent
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
		
		-- Draw destination room number
		if self.destinationRoomNumber then
			love.graphics.setColor(1, 1, 1, 1) -- White text
			local text = "Room " .. tostring(self.destinationRoomNumber)
			-- Center text
			local font = love.graphics.getFont()
			local textWidth = font:getWidth(text)
			local textHeight = font:getHeight()
			love.graphics.print(text, self.x + (self.width - textWidth)/2, self.y + (self.height - textHeight)/2)
		end
		
		love.graphics.setColor(1, 1, 1) -- Reset color
	end
end

function Door:remove()
	if self.world then
		self.world:remove(self)
	end
end

return Door
