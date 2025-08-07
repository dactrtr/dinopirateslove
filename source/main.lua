local moonshine = require "libraries/moonshine"
local sceneManager = require "sceneManager"
local titleScene = require "scenes/titleScene"
local gameScene = require "scenes/gameScene"
local PlayerData = require 'assets/data/PlayerDataTables'
local tileMapData = require 'assets/data/tilemap'

-- Virtual resolution constants
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
	love.graphics.setDefaultFilter("nearest", "nearest")
	
	font = love.graphics.newFont(20)
	love.graphics.setFont(font)
	
	canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
	
	-- Calculate initial scaling
	updateScale()
	
	-- Configure CRT effect with moonshine (let moonshine handle scaling)
	crt_effect = moonshine(moonshine.effects.scanlines)
		.chain(moonshine.effects.crt)
		.chain(moonshine.effects.chromasep)  -- Add chromatic aberration
		-- .chain(moonshine.effects.glow)
	
	-- Set CRT parameters once (moonshine will handle scaling)
	crt_effect.scanlines.width = 0.5
	crt_effect.scanlines.frequency = 240
	crt_effect.scanlines.phase = 1
	crt_effect.scanlines.thickness = 0.5
	crt_effect.scanlines.opacity = 0.4
	
	crt_effect.crt.distortionFactor = {1.02, 1.02}
	crt_effect.crt.scaleFactor = {1, 1}
	crt_effect.crt.feather = 0.02
	
	-- Configure chromatic aberration (subtle effect)
	crt_effect.chromasep.radius = 2.0    -- How far apart the color channels are
	crt_effect.chromasep.angle = 0       -- Direction of the aberration (0 = horizontal)
	
	-- crt_effect.glow.strength = 1.0
	-- crt_effect.glow.min_luma = 0.7  -- Fixed: was 1, now only bright colors glow
	
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
	joysticks = love.joystick.getJoysticks()
	
	if #joysticks > 0 then
		activeJoystick = joysticks[1]
	end
end

function updateScale()
	local screenWidth = love.graphics.getWidth()
	local screenHeight = love.graphics.getHeight()
	
	-- Calculate scale to fit virtual resolution in the screen
	local scaleX = screenWidth / VIRTUAL_WIDTH
	local scaleY = screenHeight / VIRTUAL_HEIGHT
	
	-- Use the smaller scale to maintain aspect ratio
	scale = math.min(scaleX, scaleY)
	
	-- Calculate offset to center the game
	offsetX = (screenWidth - VIRTUAL_WIDTH * scale) / 2
	offsetY = (screenHeight - VIRTUAL_HEIGHT * scale) / 2
	
	-- Resize moonshine's internal canvas (it handles scaling automatically)
	if crt_effect then
		crt_effect.resize(screenWidth, screenHeight)
	end
end

function love.resize(w, h)
	-- Small delay to ensure window dimensions are updated
	love.timer.sleep(0.01)
	updateScale()
end

function love.update(dt)
	sceneManager.update(dt)
	
	if activeJoystick then
		handleGamepadInput(dt)
	end
end

function handleGamepadInput(dt)
	local leftX = activeJoystick:getGamepadAxis("leftx")
	local leftY = activeJoystick:getGamepadAxis("lefty")
	
	local deadzone = 0.3
	local moveLeft = leftX < -deadzone or activeJoystick:isGamepadDown("dpleft")
	local moveRight = leftX > deadzone or activeJoystick:isGamepadDown("dpright")
	local moveUp = leftY < -deadzone or activeJoystick:isGamepadDown("dpup")
	local moveDown = leftY > deadzone or activeJoystick:isGamepadDown("dpdown")
	
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
	love.graphics.clear(0.1, 0.1, 0.1, 1)
	
	-- Render to virtual canvas
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	sceneManager.draw()
	love.graphics.setCanvas()
	
	-- Draw scaled game
	love.graphics.setColor(1, 1, 1, 1)
	
	if crtEnabled then
		crt_effect(function()
			love.graphics.push()
			love.graphics.translate(offsetX, offsetY)
			love.graphics.scale(scale, scale)
			love.graphics.draw(canvas, 0, 0)
			love.graphics.pop()
		end)
	else
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
	elseif key == "f" then
		local wasFullscreen = love.window.getFullscreen()
		love.window.setFullscreen(not wasFullscreen)
		love.timer.sleep(0.02)
		updateScale()
	end
	-- Removed the ESC key handler - let scenes handle their own ESC logic
	sceneManager.keypressed(key)
end

function love.gamepadpressed(joystick, button)
	if joystick == activeJoystick and sceneManager.gamepadpressed then
		sceneManager.gamepadpressed(button)
	end
end

function love.gamepadreleased(joystick, button)
	if joystick == activeJoystick and sceneManager.gamepadreleased then
		sceneManager.gamepadreleased(button)
	end
end

function love.joystickadded(joystick)
	if not activeJoystick then
		activeJoystick = joystick
	end
	table.insert(joysticks, joystick)
end

function love.joystickremoved(joystick)
	if activeJoystick == joystick then
		activeJoystick = joysticks[1] -- Switch to next available gamepad
	end
	
	for i, j in ipairs(joysticks) do
		if j == joystick then
			table.remove(joysticks, i)
			break
		end
	end
end

function love.mousepressed(x, y, button, istouch, presses)
	local virtualX = (x - offsetX) / scale
	local virtualY = (y - offsetY) / scale
	
	if virtualX >= 0 and virtualX <= VIRTUAL_WIDTH and virtualY >= 0 and virtualY <= VIRTUAL_HEIGHT then
		if sceneManager.mousepressed then
			sceneManager.mousepressed(virtualX, virtualY, button, istouch, presses)
		end
	end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	local virtualX = (x - offsetX) / scale
	local virtualY = (y - offsetY) / scale
	
	if virtualX >= 0 and virtualX <= VIRTUAL_WIDTH and virtualY >= 0 and virtualY <= VIRTUAL_HEIGHT then
		if sceneManager.touchpressed then
			sceneManager.touchpressed(id, virtualX, virtualY, dx, dy, pressure)
		end
	end
end