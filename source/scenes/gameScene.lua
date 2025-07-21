local sceneManager = require "sceneManager"

local gameScene = {
	player = {
		x = 200,
		y = 120,
		speed = 100
	},
	message = "Welcome to the Game! Use WASD to move, ESC to return to title."
}

function gameScene.load()
	-- Initialize game scene resources here
	-- Reset player position
	gameScene.player.x = 200
	gameScene.player.y = 120
end

function gameScene.update(dt)
	-- Simple player movement
	if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
		gameScene.player.y = gameScene.player.y - gameScene.player.speed * dt
	end
	if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
		gameScene.player.y = gameScene.player.y + gameScene.player.speed * dt
	end
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
		gameScene.player.x = gameScene.player.x - gameScene.player.speed * dt
	end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
		gameScene.player.x = gameScene.player.x + gameScene.player.speed * dt
	end
	
	-- Keep player on screen
	gameScene.player.x = math.max(10, math.min(love.graphics.getWidth() - 10, gameScene.player.x))
	gameScene.player.y = math.max(10, math.min(love.graphics.getHeight() - 10, gameScene.player.y))
end

function gameScene.draw()
	-- Dark background for game
	love.graphics.setColor(0.1, 0.1, 0.2)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
	
	-- Draw player as a simple rectangle
	love.graphics.setColor(0, 1, 0)  -- Green player
	love.graphics.rectangle("fill", gameScene.player.x - 10, gameScene.player.y - 10, 20, 20)
	
	-- Draw game message
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf(gameScene.message, 10, 10, love.graphics.getWidth() - 20, "left")
	
	-- Draw instructions
	love.graphics.printf("ESC - Return to Title", 10, love.graphics.getHeight() - 30, love.graphics.getWidth() - 20, "left")
	
	love.graphics.setColor(1, 1, 1)  -- Reset color
end

function gameScene.keypressed(key)
	if key == "escape" then
		-- Return to title with slide transition
		sceneManager.startTransition("game", "title", "slide")
	end
end

return gameScene