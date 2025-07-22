local sceneManager = require "sceneManager"
local Timer = require 'libraries/hump/timer'  -- Para timers y tweens
local bump = require 'libraries/bump'          -- Para físicas
local Player = require 'entities.Player'

local gameScene = {
	player = nil,
	message = "Welcome to the Game! Use WASD to move, ESC to return to title.",
	world = nil,  -- BUMP world
	timer = nil   -- HUMP timer
}

function gameScene.load()
	-- Initialize game scene resources here
	
	-- Initialize BUMP world for physics
	gameScene.world = bump.newWorld(32) -- 32 = cell size
	
	-- Initialize HUMP timer
	gameScene.timer = Timer.new()
	
	-- Instanciar al jugador con físicas
	gameScene.player = Player(200, 120, gameScene.world)
end

function gameScene.update(dt)
	-- Update HUMP timer
	gameScene.timer:update(dt)
	
	-- Actualizar jugador
	gameScene.player:update(dt)
	-- Keep player on screen (backup boundary check)
	gameScene.player.x = math.max(10, math.min(love.graphics.getWidth() - 10, gameScene.player.x))
	gameScene.player.y = math.max(10, math.min(love.graphics.getHeight() - 10, gameScene.player.y))
end

function gameScene.draw()
	-- Dark background for game
	-- Dibujar al jugador
	gameScene.player:draw()
	
	-- Draw player as a simple rectangle
	love.graphics.setColor(0, 1, 0)  -- Green player
	-- love.graphics.rectangle("fill", gameScene.player.x - 10, gameScene.player.y - 10, 20, 20)
	
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