-- Door.lua
-- Door entity for room transitions in Love2D

local Door = {}
Door.__index = Door

-- Position mapping for doors based on direction
-- Positions are calculated to center doors in wall gaps
local positions = {
	-- Right: gap at y=122, door height=50, so y = 122 - 25 = 97
	-- x at right edge minus door width: 400 - 16 = 384
	right = {x = 384, y = 97},
	
	-- Left: gap at y=122, door height=50, so y = 122 - 25 = 97
	-- x at left edge: 0
	left = {x = 0, y = 97},
	
	-- Down: gap at x=203, door width=50, so x = 203 - 25 = 178
	-- y at bottom edge minus door height: 240 - 16 = 224
	down = {x = 178, y = 224},
	
	-- Top: gap at x=203, door width=50, so x = 203 - 25 = 178
	-- y at top edge: 0
	top = {x = 178, y = 0}
}

-- Collision rectangle sizes based on direction
local function getCollisionRect(direction)
	local rects = {
		right = {w = 16, h = 50},
		left = {w = 14, h = 50},
		down = {w = 50, h = 16},
		top = {w = 50, h = 16}
	}
	return rects[direction]
end

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
		nw = "top"     -- northwest -> top
	}
	
	local converted = conversion[ldtkDir]
	if not converted then
		print("⚠️ WARNING: Unknown door direction '" .. tostring(ldtkDir) .. "', defaulting to 'right'")
		return "right"  -- Safe fallback
	end
	
	return converted
end

function Door.new(direction, status, nextLevelIid, world)
	local self = setmetatable({}, Door)
	
	-- Convert direction if needed
	self.direction = convertDirection(direction)
	self.status = status or "open"  -- "open" or "closed"
	self.nextLevelIid = nextLevelIid
	
	-- Get position for this direction
	local pos = positions[self.direction]
	self.x = pos.x
	self.y = pos.y
	
	-- Get collision rectangle
	local rect = getCollisionRect(self.direction)
	self.width = rect.w
	self.height = rect.h
	
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

function Door:prevRoom(direction)
	-- Set spawn coordinates for the player when entering from this direction
	local spawnCoordinates = {
		top = {x = 196, y = 196},
		down = {x = 196, y = 32},
		right = {x = 32, y = 116},
		left = {x = 364, y = 116}
	}
	
	-- Store spawn position (will be used by gameScene)
	self.spawnX = spawnCoordinates[direction].x
	self.spawnY = spawnCoordinates[direction].y
	
	print("📍 Setting spawn for direction " .. direction .. ": (" .. self.spawnX .. ", " .. self.spawnY .. ")")
end

function Door:update(dt)
	-- Doors don't need update logic for now
end

function Door:draw()
	-- Optional: Draw debug rectangles for doors
	if DRAW_DEBUG_DOORS then
		love.graphics.setColor(0, 1, 0, 0.3)  -- Green semi-transparent
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
		love.graphics.setColor(1, 1, 1)  -- Reset color
	end
end

function Door:remove()
	if self.world then
		self.world:remove(self)
	end
end

return Door
