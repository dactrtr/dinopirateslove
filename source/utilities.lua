-- utilities.lua
-- Utility functions for debugging and game helpers

local utilities = {}

-- MARK: Spawn Coordinates
-- Single source of truth for player spawn coordinates
-- These coordinates represent the CENTER of the player sprite
utilities.spawnCoordinates = {
	top = {x = 196, y = 200},
	down = {x = 196, y = 16},
	right = {x = 32+16, y = 116},
	left = {x = 364-16, y = 116}
}

-- MARK: Debug Drawing Functions

-- Draw spawn coordinate rectangles
function utilities.drawSpawnPoints(spawnCoordinates)
	love.graphics.setColor(1, 1, 0, 0.5) -- Yellow semi-transparent
	
	for direction, spawn in pairs(spawnCoordinates) do
		-- Draw rectangle centered on spawn point
		local rectSize = 48
		love.graphics.rectangle("fill", spawn.x - rectSize/2, spawn.y - rectSize/2, rectSize, rectSize)
		
		-- Draw label
		love.graphics.setColor(1, 1, 1, 1) -- White text
		local text = direction
		local font = love.graphics.getFont()
		local textWidth = font:getWidth(text)
		love.graphics.print(text, spawn.x - textWidth/2, spawn.y - rectSize/2 - 12)
		
		-- Reset color for next iteration
		love.graphics.setColor(1, 1, 0, 0.5)
	end
	
	love.graphics.setColor(1, 1, 1) -- Reset color
end

-- Draw collision boxes for entities
function utilities.drawCollisionBox(x, y, w, h, color)
	color = color or {0, 1, 1, 0.3} -- Default: cyan semi-transparent
	love.graphics.setColor(color[1], color[2], color[3], color[4])
	love.graphics.rectangle("line", x, y, w, h)
	love.graphics.setColor(1, 1, 1) -- Reset color
end

-- Draw all player collision boxes
function utilities.drawPlayerCollision(player)
	if player then
		local px, py, pw, ph = player:getCollisionRect()
		utilities.drawCollisionBox(px, py, pw, ph, {0, 1, 1, 0.3}) -- Cyan
	end
end

-- Draw all enemy collision boxes
function utilities.drawEnemiesCollision(enemies)
	for _, enemy in ipairs(enemies) do
		if enemy.x and enemy.y and enemy.width and enemy.height then
			-- Account for collision offset if it exists
			local offsetX = enemy.collisionOffsetX or 0
			local offsetY = enemy.collisionOffsetY or 0
			utilities.drawCollisionBox(
				enemy.x + offsetX, 
				enemy.y + offsetY, 
				enemy.width, 
				enemy.height, 
				{1, 0, 1, 0.3} -- Magenta
			)
		end
	end
end

-- Draw wall rectangles
function utilities.drawWalls(walls)
	love.graphics.setColor(1, 0, 0, 1) -- Red color
	for _, wall in ipairs(walls) do
		love.graphics.rectangle("fill", wall.x, wall.y, wall.w, wall.h)
	end
	love.graphics.setColor(1, 1, 1) -- Reset color
end

-- Draw doors (for debugging)
function utilities.drawDoors(doors)
	for i, door in ipairs(doors) do
		if door.draw then
			door:draw()
		end
	end
end

-- MARK: Complete Debug Draw Function
-- All-in-one debug drawing function
function utilities.drawDebugInfo(gameScene)
	if not gameScene.debugMode then return end
	
	-- Draw walls
	utilities.drawWalls(gameScene.walls)
	
	-- Draw doors
	utilities.drawDoors(gameScene.doors)
	
	-- Draw collision boxes
	utilities.drawPlayerCollision(gameScene.player)
	utilities.drawEnemiesCollision(gameScene.enemies)
	
	-- Draw spawn coordinates
	utilities.drawSpawnPoints(utilities.spawnCoordinates)
end

-- Create optimized wall colliders from tile data
function utilities.CreateTileColliders(tileData, world, tileSize, offsetX, offsetY)
	tileSize = tileSize or 16
	offsetX = offsetX or 0
	offsetY = offsetY or 0
	local height = #tileData
	local width = #tileData[1]
	local wallSegments = {}

	-- SECTION_TILE_IDS: tiles that are NOT walls (floor)
	-- According to TILE_LOADING.md, ID 5 is the floor.
	local SECTION_TILE_IDS = { [5] = true }

	-- Phase 1: Horizontal Identification
	for y = 1, height do
		local startX = nil
		for x = 1, width do
			local tileId = tileData[y][x]
			local isWall = not SECTION_TILE_IDS[tileId]
			
			if isWall then
				if not startX then startX = x end
			else
				if startX then
					table.insert(wallSegments, {x = startX, y = y, w = x - startX, h = 1})
					startX = nil
				end
			end
		end
		if startX then
			table.insert(wallSegments, {x = startX, y = y, w = width - startX + 1, h = 1})
		end
	end

	-- Phase 2: Vertical Merging
	local mergedSegments = {}
	local processed = {}
	
	for i, seg in ipairs(wallSegments) do
		if not processed[i] then
			local currentX = seg.x
			local currentY = seg.y
			local currentW = seg.w
			local currentH = seg.h
			processed[i] = true
			
			-- Look for segments below that match perfectly in X and Width
			local nextY = currentY + 1
			while nextY <= height do
				local foundMatch = false
				for j = i + 1, #wallSegments do
					local other = wallSegments[j]
					if not processed[j] and other.y == nextY and other.x == currentX and other.w == currentW then
						currentH = currentH + 1
						processed[j] = true
						foundMatch = true
						break
					end
				end
				if not foundMatch then break end
				nextY = nextY + 1
			end
			
			-- Create the final wall object
			local wall = {
				x = offsetX + (currentX - 1) * tileSize,
				y = offsetY + (currentY - 1) * tileSize,
				w = currentW * tileSize,
				h = currentH * tileSize,
				isWall = true
			}
			
			-- Add to BUMP world
			world:add(wall, wall.x, wall.y, wall.w, wall.h)
			table.insert(mergedSegments, wall)
		end
	end

	return mergedSegments
end

return utilities
