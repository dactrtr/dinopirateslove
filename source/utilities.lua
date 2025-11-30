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

return utilities
