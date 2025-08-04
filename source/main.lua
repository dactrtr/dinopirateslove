local moonshine = require "libraries/moonshine"
local sceneManager = require "sceneManager"
local titleScene = require "scenes/titleScene"
local gameScene = require "scenes/gameScene"
local PlayerData = require 'assets/data/PlayerDataTables'

-- Virtual resolution constants (define these first!)
VIRTUAL_WIDTH = 400
VIRTUAL_HEIGHT = 240

-- Global variables
local crt_effect
local font
local canvas -- offscreen render target for virtual resolution
local crtEnabled = true

-- Scaling variables
local scale = 1
local offsetX = 0
local offsetY = 0

-- Gamepad variables
local joysticks = {}
local activeJoystick = nil

function love.load()
	love.graphics.setDefaultFilter("nearest", "nearest") -- avoid blurry scaling
	
	font = love.graphics.newFont(20)
	love.graphics.setFont(font)
	
	-- Make sure canvas is created with correct dimensions
	canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
	print("Canvas created:", VIRTUAL_WIDTH, "x", VIRTUAL_HEIGHT) -- Debug output
	print("Screen size:", love.graphics.getWidth(), love.graphics.getHeight())
	
	-- Calculate initial scaling for fullscreen
	updateScale()
	print("Initial scale:", scale)
	
	-- Configure CRT effect with moonshine
	crt_effect = moonshine(moonshine.effects.scanlines)
		.chain(moonshine.effects.crt)
		.chain(moonshine.effects.glow)
	
	-- Configure scanlines (initial values, will be updated by updateCRTScale)
	crt_effect.scanlines.width = 0.5
	crt_effect.scanlines.frequency = 240
	crt_effect.scanlines.phase = 1
	crt_effect.scanlines.thickness = 0.5
	crt_effect.scanlines.opacity = 0.4
	
	-- Configure CRT distortion
	crt_effect.crt.distortionFactor = {1.02, 1.02}
	crt_effect.crt.scaleFactor = {1, 1}
	crt_effect.crt.feather = 0.02
	
	-- Configure glow
	crt_effect.glow.strength = 1.0
	crt_effect.glow.min_luma = 1
	
	-- Update CRT effect for initial scale
	updateCRTScale()
	
	-- Initialize scenes
	sceneManager.init()
	sceneManager.registerScene("title", titleScene)
	sceneManager.registerScene("game", gameScene)
	sceneManager.setCurrentScene("title")
	
	titleScene.load()
	gameScene.load()
	
	-- Initialize gamepad support
	initGamepads()
end

function initGamepads()
	-- Get all connected joysticks
	joysticks = love.joystick.getJoysticks()
	
	-- Use the first connected gamepad
	if #joysticks > 0 then
		activeJoystick = joysticks[1]
		print("Gamepad connected:", activeJoystick:getName())
	else
		print("No gamepad detected")
	end
end

function updateScale()
	-- Get actual screen dimensions
	local screenWidth = love.graphics.getWidth()
	local screenHeight = love.graphics.getHeight()
	
	print("Updating scale - Screen size:", screenWidth, "x", screenHeight)
	
	-- Calculate scale to fit virtual resolution in the screen
	local scaleX = screenWidth / VIRTUAL_WIDTH
	local scaleY = screenHeight / VIRTUAL_HEIGHT
	
	-- Use the smaller scale to maintain aspect ratio (pillarbox/letterbox)
	scale = math.min(scaleX, scaleY)
	
	-- Calculate offset to center the game
	offsetX = (screenWidth - VIRTUAL_WIDTH * scale) / 2
	offsetY = (screenHeight - VIRTUAL_HEIGHT * scale) / 2
	
	print("Scale calculated:", scale, "Offset:", offsetX, offsetY)
	
	-- IMPORTANT: Resize moonshine's internal canvas to match screen size
	if crt_effect then
		crt_effect.resize(screenWidth, screenHeight)
		print("Moonshine canvas resized to:", screenWidth, "x", screenHeight)
	end
	
	-- Update CRT effect parameters
	updateCRTScale()
end

function updateCRTScale()
	if crt_effect then
		-- Debug: Check if scale is valid
		if not scale or scale <= 0 then
			print("ERROR: Invalid scale value:", scale)
			return
		end
		
		-- Adjust scanlines frequency based on scale to maintain consistent appearance
		local baseFrequency = 240
		crt_effect.scanlines.frequency = baseFrequency * scale
		
		-- Adjust scanline width and thickness based on scale
		crt_effect.scanlines.width = math.max(0.1, 0.5 / scale)
		crt_effect.scanlines.thickness = math.max(0.1, 0.5 / scale)
		
		-- Adjust CRT distortion factor - less distortion for smaller scales
		local baseDist = 1.02
		local distortionAmount = 1 + (baseDist - 1) * math.min(scale, 2.0) -- Cap the distortion scaling
		crt_effect.crt.distortionFactor = {distortionAmount, distortionAmount}
		
		-- Adjust feather (edge softness) based on scale
		local baseFeather = 0.02
		local featherValue = baseFeather / scale
		crt_effect.crt.feather = featherValue
		
		-- Adjust glow strength based on scale
		local baseGlow = 1.0
		local glowValue = baseGlow * math.min(scale * 0.5, 1.5) -- Scale glow but cap it
		crt_effect.glow.strength = glowValue
		
		-- Safe debug output with nil checks
		print("CRT scale updated:")
		print("  Scale:", scale or "nil")
		print("  Frequency:", crt_effect.scanlines.frequency or "nil")
		print("  Distortion:", distortionAmount or "nil")
		print("  Feather:", featherValue or "nil")
		print("  Glow:", glowValue or "nil")
	else
		print("ERROR: crt_effect is nil")
	end
end

function love.resize(w, h)
	-- Recalculate scaling when window is resized
	print("Window resized to:", w, "x", h)
	
	-- Small delay to ensure window dimensions are properly updated
	love.timer.sleep(0.01)
	
	updateScale()
	print("New scale after resize:", scale)
	
	-- Force CRT update even if it's currently disabled (for when it gets re-enabled)
	if crt_effect then
		updateCRTScale()
		print("CRT parameters updated after resize")
	end
end

function love.update(dt)
	sceneManager.update(dt)
	
	-- Handle gamepad input
	if activeJoystick then
		handleGamepadInput(dt)
	end
end

function handleGamepadInput(dt)
	-- D-pad or left stick for movement
	local leftX = activeJoystick:getGamepadAxis("leftx")
	local leftY = activeJoystick:getGamepadAxis("lefty")
	
	-- Convert analog stick to digital input (deadzone of 0.3)
	local deadzone = 0.3
	local moveLeft = leftX < -deadzone or activeJoystick:isGamepadDown("dpleft")
	local moveRight = leftX > deadzone or activeJoystick:isGamepadDown("dpright")
	local moveUp = leftY < -deadzone or activeJoystick:isGamepadDown("dpup")
	local moveDown = leftY > deadzone or activeJoystick:isGamepadDown("dpdown")
	
	-- Pass gamepad input to scene manager (you'll need to implement this in your scenes)
	if sceneManager.gamepadInput then
		sceneManager.gamepadInput({
			left = moveLeft,
			right = moveRight,
			up = moveUp,
			down = moveDown,
			a = activeJoystick:isGamepadDown("a"),
			b = activeJoystick:isGamepadDown("b"),
			x = activeJoystick:isGamepadDown("x"),
			y = activeJoystick:isGamepadDown("y"),
			start = activeJoystick:isGamepadDown("start"),
			back = activeJoystick:isGamepadDown("back")
		})
	end
end

function love.draw()
	-- Clear the screen with dark gray (easier to see than pure black)
	love.graphics.clear(0.1, 0.1, 0.1, 1)
	
	-- Render everything to the canvas first
	love.graphics.setCanvas(canvas)
	love.graphics.clear() -- Clear canvas
	
	-- Draw your scenes to the virtual canvas
	sceneManager.draw()
	
	-- Reset to screen
	love.graphics.setCanvas()
	
	-- Draw the scaled game with or without CRT effect
	drawScaledGame()
end

function drawScaledGame()
	-- Make sure color is reset before drawing
	love.graphics.setColor(1, 1, 1, 1)
	
	if crtEnabled then
		-- Apply CRT effect to the scaled game (moonshine handles the canvas internally now)
		crt_effect(function()
			-- Apply scaling and centering
			love.graphics.push()
			love.graphics.translate(offsetX, offsetY)
			love.graphics.scale(scale, scale)
			love.graphics.draw(canvas, 0, 0)
			love.graphics.pop()
		end)
	else
		-- Draw the canvas without CRT effect
		love.graphics.push()
		love.graphics.translate(offsetX, offsetY)
		love.graphics.scale(scale, scale)
		love.graphics.draw(canvas, 0, 0)
		love.graphics.pop()
	end
end

function love.keypressed(key)
	if key == "q" then
		crtEnabled = not crtEnabled
		-- Always update CRT parameters when toggling, using current screen size
		updateScale() -- This ensures we have the latest scale
		print("CRT effect:", crtEnabled and "ON" or "OFF", "- Scale:", scale)
	elseif key == "f" then
		-- Toggle fullscreen
		local wasFullscreen = love.window.getFullscreen()
		love.window.setFullscreen(not wasFullscreen)
		
		-- Force update after fullscreen toggle
		love.timer.sleep(0.02) -- Small delay for window to update
		updateScale()
		print("Fullscreen toggled:", not wasFullscreen, "- New scale:", scale)
	elseif key == "escape" then
		love.event.quit()
	end
	sceneManager.keypressed(key)
end

-- Gamepad button press events
function love.gamepadpressed(joystick, button)
	if joystick == activeJoystick then
		-- Handle special buttons
		if button == "start" then
			-- Pause or menu
		elseif button == "back" then
			-- Back or settings
		end
		
		-- Pass to scene manager
		if sceneManager.gamepadpressed then
			sceneManager.gamepadpressed(button)
		end
	end
end

function love.gamepadreleased(joystick, button)
	if joystick == activeJoystick and sceneManager.gamepadreleased then
		sceneManager.gamepadreleased(button)
	end
end

-- Handle gamepad connection/disconnection
function love.joystickadded(joystick)
	print("Gamepad connected:", joystick:getName())
	if not activeJoystick then
		activeJoystick = joystick
	end
	table.insert(joysticks, joystick)
end

function love.joystickremoved(joystick)
	print("Gamepad disconnected:", joystick:getName())
	if activeJoystick == joystick then
		activeJoystick = joysticks[1] -- Switch to next available gamepad
	end
	
	-- Remove from joysticks table
	for i, j in ipairs(joysticks) do
		if j == joystick then
			table.remove(joysticks, i)
			break
		end
	end
end

-- Optional: Input handling with coordinate conversion for mouse/touch
function love.mousepressed(x, y, button, istouch, presses)
	-- Convert screen coordinates to virtual coordinates
	local virtualX = (x - offsetX) / scale
	local virtualY = (y - offsetY) / scale
	
	-- Only process if click is within virtual screen bounds
	if virtualX >= 0 and virtualX <= VIRTUAL_WIDTH and virtualY >= 0 and virtualY <= VIRTUAL_HEIGHT then
		-- Pass virtual coordinates to your scene manager if it supports mouse input
		if sceneManager.mousepressed then
			sceneManager.mousepressed(virtualX, virtualY, button, istouch, presses)
		end
	end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	-- Convert screen coordinates to virtual coordinates for mobile
	local virtualX = (x - offsetX) / scale
	local virtualY = (y - offsetY) / scale
	
	-- Only process if touch is within virtual screen bounds
	if virtualX >= 0 and virtualX <= VIRTUAL_WIDTH and virtualY >= 0 and virtualY <= VIRTUAL_HEIGHT then
		-- Pass virtual coordinates to your scene manager if it supports touch input
		if sceneManager.touchpressed then
			sceneManager.touchpressed(id, virtualX, virtualY, dx, dy, pressure)
		end
	end
end