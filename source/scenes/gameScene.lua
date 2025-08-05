local sceneManager = require "sceneManager"
local Timer = require 'libraries/hump/timer'
local bump = require 'libraries/bump'
local Player = require 'entities.Player'

-- Simple require for PauseMenu
local PauseMenu = require 'PauseMenu'

local gameScene = {
	player = nil,
	world = nil,
	timer = nil,
	pauseMenu = nil
}

local padding = 8
local playerSize = 48

function gameScene.load()
	-- Initialize BUMP world for physics
	gameScene.world = bump.newWorld(32) -- 32 = cell size
	
	-- Initialize HUMP timer
	gameScene.timer = Timer.new()
	
	-- Create player
	gameScene.player = Player(200, 120, gameScene.world)
	
	-- Initialize pause menu with custom buttons for this scene
	gameScene.pauseMenu = PauseMenu.new({
		{text = "Resume", action = "resume"},
		{text = "Return to Title", action = "title"},
		{text = "Quit Game", action = "quit"}
	})
end

function gameScene.update(dt)
	-- Update pause menu
	gameScene.pauseMenu:update(dt)
	
	-- Only update game if menu is not shown
	if not gameScene.pauseMenu:isVisible() then
		-- Update timer and player
		gameScene.timer:update(dt)
		gameScene.player:update(dt)
		
		-- Keep player on screen (boundary check)
		gameScene.player.x = math.max(padding, math.min(VIRTUAL_WIDTH - padding - playerSize, gameScene.player.x))
		gameScene.player.y = math.max(padding, math.min(VIRTUAL_HEIGHT - padding - playerSize, gameScene.player.y))
	end
end

function gameScene.draw()
	-- Draw boundary box
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", padding, padding, VIRTUAL_WIDTH - 2 * padding, VIRTUAL_HEIGHT - 2 * padding)
	
	-- Draw player collision box
	love.graphics.setColor(0, 1, 1, 0.5)
	love.graphics.rectangle("line", gameScene.player.x, gameScene.player.y, playerSize, playerSize)
	
	-- Draw player
	love.graphics.setColor(1, 1, 1) -- Reset color before player draw
	gameScene.player:draw()
	
	-- Draw instructions (only if menu is not shown)
	if not gameScene.pauseMenu:isVisible() then
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("Press ESC or START for menu", 10, VIRTUAL_HEIGHT - 30, VIRTUAL_WIDTH - 20, "left")
	end
	
	-- Draw pause menu overlay
	gameScene.pauseMenu:draw()
end

function gameScene.keypressed(key)
	-- Let pause menu handle its own input first
	local action = gameScene.pauseMenu:keypressed(key)
	if action then
		-- Handle menu actions
		gameScene.handleMenuAction(action)
		return
	end
	
	-- Game input (when menu is not shown)
	if key == "escape" then
		-- Show menu
		gameScene.pauseMenu:show()
	end
end

function gameScene.gamepadInput(input)
	-- Let pause menu handle gamepad input first
	local action = gameScene.pauseMenu:gamepadInput(input)
	if action then
		-- Handle menu actions
		gameScene.handleMenuAction(action)
		return
	end
	
	-- Pass gamepad input to player when menu is not shown
	if not gameScene.pauseMenu:isVisible() then
		if gameScene.player and gameScene.player.handleGamepadInput then
			gameScene.player:handleGamepadInput(input)
		end
	end
end

-- Handle actions returned by the pause menu
function gameScene.handleMenuAction(action)
	if action == "resume" then
		-- Menu is already hidden by the PauseMenu component
		-- Nothing else needed for resume
	elseif action == "title" then
		sceneManager.startTransition("game", "title", "slide")
	elseif action == "quit" then
		love.event.quit()
	end
end

return gameScene