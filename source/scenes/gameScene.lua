local sceneManager = require "sceneManager"
local config = require "config"
local Timer = require 'libraries/hump/timer'  -- Para timers y tweens
local bump = require 'libraries/bump'          -- Para físicas
local Player = require 'entities.Player'

local gameScene = {
	player = nil,
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
	local padding = 48
	local playerW = 48
	local playerH = 48
	
	gameScene.player.x = math.max(padding, math.min(config.VIRTUAL_WIDTH - padding - playerW, gameScene.player.x))
	gameScene.player.y = math.max(padding, math.min(config.VIRTUAL_HEIGHT - padding - playerH, gameScene.player.y))
end

function gameScene.draw()
	-- Dark background for game
	-- Dibujar al jugador
	-- Draw visible boundary box (padding area)
	local padding = 48
	love.graphics.setColor(1, 1, 1, 1) -- Semi-transparent white
	love.graphics.rectangle("line", padding, padding, config.VIRTUAL_WIDTH - 2 * padding, config.VIRTUAL_HEIGHT - 2 * padding)
	love.graphics.setColor(1, 1, 1) -- Reset color
	gameScene.player:draw()
	
	-- Draw player as a simple rectangle
	love.graphics.setColor(0, 1, 0)  -- Green player
	-- love.graphics.rectangle("fill", gameScene.player.x - 10, gameScene.player.y - 10, 20, 20)
	
	-- Draw game message
	love.graphics.setColor(1, 1, 1)

	
	-- Draw instructions
	love.graphics.printf("ESC - Return to Title", 10, config.VIRTUAL_HEIGHT - 30, config.VIRTUAL_WIDTH - 20, "left")
	
	love.graphics.setColor(1, 1, 1)  -- Reset color
end

function gameScene.keypressed(key)
	if key == "escape" then
		-- Return to title with slide transition
		sceneManager.startTransition("game", "title", "slide")
	end
end

return gameScene