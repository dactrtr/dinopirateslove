-- entities/player/collisions.lua
-- Collision-related functions for Player

local collisions = {}

-- Get the collision box position and dimensions
function collisions.getCollisionRect(player)
	return player.x + player.collisionOffsetX, player.y + player.collisionOffsetY, player.width, player.height
end

-- Get the sprite position and dimensions (for drawing)
function collisions.getSpriteRect(player)
	return player.x, player.y, player.spriteWidth, player.spriteHeight
end

-- Update collision box position in BUMP world
function collisions.updateCollisionPosition(player)
	local collisionX = player.x + player.collisionOffsetX
	local collisionY = player.y + player.collisionOffsetY
	player.world:update(player, collisionX, collisionY)
end

-- Returns a table of colliding objects within the specified rectangle
-- @param x, y: top-left corner of the rectangle
-- @param w, h: width and height of the rectangle
-- @param filter: optional collision filter function
function collisions.collideRect(player, x, y, w, h, filter)
	local items, len = player.world:queryRect(x, y, w, h, filter)
	
	-- Format results similar to Playdate SDK
	local collisionList = {}
	for i = 1, len do
		local item = items[i]
		if item ~= player then -- Don't include self in collisions
			local itemX, itemY, itemW, itemH = player.world:getRect(item)
			table.insert(collisionList, {
				object = item,
				x = itemX,
				y = itemY,
				width = itemW,
				height = itemH
			})
		end
	end
	
	return collisionList, #collisionList
end

-- Check for collisions at the player's current collision box position
function collisions.checkCollisions(player)
	local collisionX, collisionY = player.x + player.collisionOffsetX, player.y + player.collisionOffsetY
	return collisions.collideRect(player, collisionX, collisionY, player.width, player.height)
end

-- Check for collisions at a specific sprite position (converts to collision box position)
function collisions.checkCollisionsAt(player, spriteX, spriteY)
	local collisionX = spriteX + player.collisionOffsetX
	local collisionY = spriteY + player.collisionOffsetY
	return collisions.collideRect(player, collisionX, collisionY, player.width, player.height)
end

-- Check for collisions in a specific direction from current position
function collisions.checkCollisionsInDirection(player, direction, distance)
	local checkX, checkY = player.x, player.y
	
	if direction == "up" then
		checkY = checkY - distance
	elseif direction == "down" then
		checkY = checkY + distance
	elseif direction == "left" then
		checkX = checkX - distance
	elseif direction == "right" then
		checkX = checkX + distance
	end
	
	return collisions.checkCollisionsAt(player, checkX, checkY)
end

-- Get all objects within a radius of the player (uses collision box center)
function collisions.getObjectsInRadius(player, radius)
	local centerX = player.x + player.collisionOffsetX + player.width / 2
	local centerY = player.y + player.collisionOffsetY + player.height / 2
	
	-- Create a square area around the player
	local x = centerX - radius
	local y = centerY - radius
	local w = radius * 2
	local h = radius * 2
	
	local collisionList, count = collisions.collideRect(player, x, y, w, h)
	
	-- Filter by actual distance for circular radius
	local filtered = {}
	for i = 1, count do
		local collision = collisionList[i]
		local objCenterX = collision.x + collision.width / 2
		local objCenterY = collision.y + collision.height / 2
		
		local distance = math.sqrt((centerX - objCenterX)^2 + (centerY - objCenterY)^2)
		if distance <= radius then
			collision.distance = distance
			table.insert(filtered, collision)
		end
	end
	
	return filtered, #filtered
end

return collisions
