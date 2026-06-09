local moonshine = require "libraries/moonshine"
local CRTDebugMenu = require 'entities.UI.CRTDebugMenu'
DEBUG = false -- Set to true to re-enable all the general debug prints
function printDebug(...)
	if DEBUG then
		print(...)
	end
end

-- Enemy-only debug channel. Always prints (independent of DEBUG) so we can trace
-- enemy behavior on an otherwise-clean console. Set ENEMY_DEBUG = false to mute.
ENEMY_DEBUG = true
function enemyLog(...)
	if ENEMY_DEBUG then
		print("🦖", ...)
	end
end
-- Config must load before everything else (other modules read it at load time)
Config = require 'assets.data.Config'
-- Expose ZIndex globally so all existing code continues to work unchanged
ZIndex = Config.ZIndex
require 'assets/data/PlayerDataTables'
local sceneManager = require "sceneManager"
local titleScene = require "scenes/titleScene"
local gameScene = require "scenes/gameScene"
local danceScene = require "scenes/DanceScene"
local cockpitScene = require "scenes/CockpitScene"
local creditsScene = require "scenes/CreditsScene"
local deadScene = require "scenes/DeadScene"
local tileMapData = require 'assets/data/tilemap'

-- Procedural run-graph globals (read Config/PlayerData/tileMapData/levelsLDTK at call time).
-- gameScene (required above) already loaded 'assets.data.levels' -> global levelsLDTK.
require 'utilities.Conditions'    -- global Conditions
require 'utilities.MapGenerator'  -- global MapGenerator
require 'RunState'                -- global RunState

-- Initialize Graphics compatibility layer BEFORE script data
Graphics = require 'libraries/graphics_compat'
Graphics.loadStrings("en.strings")

-- Load script data (defines global 'script' table)
require 'assets.data.script'


-- Virtual resolution constants
VIRTUAL_WIDTH = 400
VIRTUAL_HEIGHT = 240

-- UI constants
UI_OVERLAY_OPACITY = 0.8 -- Opacity for menu overlays and backgrounds

-- Todos los bindings están en assets/data/InputBindings.lua
Input = require 'assets.data.InputBindings'
local ControllerConfig = require 'assets.data.ControllerConfig'

-- Set DEBUG_CONTROLLER = true to print button/axis info when a gamepad is connected.
-- Useful for finding raw button indices for a new controller.
DEBUG_CONTROLLER = false

-- Global variables
crt_effect = nil -- Made global for settings menu access
local font
local canvas -- offscreen render target for virtual resolution
crtEnabled = true -- Made global for settings menu access
local aButtonHoldTimer = 0
local aButtonHoldFired = false
local MENU_HOLD_THRESHOLD = 0.5  -- segundos para abrir menú

-- Settings table for moonshine effects
moonshinSettings = {
	scanlines = {
		width = 0.5,
		frequency = 240,
		phase = 1,
		thickness = 0.5,
		opacity = 0.4
	},
	crt = {
		distortionFactor = 1.02,
		feather = 0.02
	},
	chromasep = {
		radius = 2.0,
		angle = 0
	},
	glow = {
		strength = 5,
		min_luma = 0.7
	},
	playerOutline = {
		thickness = 0,
		color = {1, 1, 1, 1}
	}
}

-- Scaling variables
local scale = 1
local offsetX = 0
local offsetY = 0

-- Gamepad variables
local joysticks = {}
local activeJoystick = nil

function applyCRTSettings()
	if not crt_effect then return end
	
	crt_effect.scanlines.width = moonshinSettings.scanlines.width
	crt_effect.scanlines.frequency = moonshinSettings.scanlines.frequency
	crt_effect.scanlines.phase = moonshinSettings.scanlines.phase
	crt_effect.scanlines.thickness = moonshinSettings.scanlines.thickness
	crt_effect.scanlines.opacity = moonshinSettings.scanlines.opacity
	
	crt_effect.crt.distortionFactor = {moonshinSettings.crt.distortionFactor, moonshinSettings.crt.distortionFactor}
	crt_effect.crt.scaleFactor = {1, 1}
	crt_effect.crt.feather = moonshinSettings.crt.feather
	
	crt_effect.chromasep.radius = moonshinSettings.chromasep.radius
	crt_effect.chromasep.angle = moonshinSettings.chromasep.angle

	crt_effect.glow.strength = moonshinSettings.glow.strength
	crt_effect.glow.min_luma = moonshinSettings.glow.min_luma
end

function love.load()
	love.graphics.setDefaultFilter("nearest", "nearest")

	-- Procedural runs need a fresh RNG each boot.
	math.randomseed(os.time())
	math.random(); math.random()  -- discard first couple (Lua 5.1 low-entropy warmup)

	font = love.graphics.newFont(20)
	love.graphics.setFont(font)
	
	canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
	
	-- Calculate initial scaling
	updateScale()
	
	-- Configure CRT effect with moonshine (let moonshine handle scaling)
	crt_effect = moonshine(moonshine.effects.scanlines)
		.chain(moonshine.effects.crt)
		.chain(moonshine.effects.chromasep)
		.chain(moonshine.effects.glow)

	-- Set CRT parameters from settings table
	applyCRTSettings()
	CRTDebugMenu.loadFromDisk()

	-- Load all scenes first
	titleScene.load()
	gameScene.load()
	creditsScene.load()
	deadScene.load()


	-- Initialize scenes
	sceneManager.init()
	sceneManager.registerScene("title", titleScene)
	sceneManager.registerScene("game", gameScene)
	sceneManager.registerScene("dance", danceScene)
	sceneManager.registerScene("cockpit", cockpitScene)
	sceneManager.registerScene("credits", creditsScene)
	sceneManager.registerScene("dead", deadScene)
	sceneManager.setCurrentScene("title")
	
	-- Initialize gamepad support
	initGamepads()
end

-- Pick a real controller, skipping virtual joysticks like the iOS accelerometer
-- (which LÖVE reports as joysticks[1] on iPad). Prefers a recognized gamepad;
-- falls back to the first non-accelerometer pad with buttons; else the first one.
function pickBestJoystick(list)
	if not list or #list == 0 then return nil end
	for _, js in ipairs(list) do
		if js:isGamepad() then return js end
	end
	for _, js in ipairs(list) do
		local n = (js:getName() or ""):lower()
		if not n:find("accelerometer", 1, true) and js:getButtonCount() > 0 then
			return js
		end
	end
	return list[1]
end

function initGamepads()
	-- Load the SDL community controller DB so unrecognized pads (8BitDo, etc.)
	-- get a proper gamepad mapping → isGamepad() == true and rightx/righty work.
	local mappings = "assets/data/gamecontrollerdb.txt"
	if love.filesystem.getInfo(mappings) then
		local ok, err = pcall(love.joystick.loadGamepadMappings, mappings)
		if ok then
			printDebug("🎮 Loaded gamepad mappings from " .. mappings)
		else
			printDebug("⚠️ Failed to load gamepad mappings: " .. tostring(err))
		end
	else
		printDebug("⚠️ Gamepad DB not found at " .. mappings)
	end

	joysticks = love.joystick.getJoysticks()

	if #joysticks > 0 then
		if DEBUG_CONTROLLER then
			print("🎮 Joysticks detected: " .. #joysticks)
			for i, js in ipairs(joysticks) do
				print(string.format("   [%d] %s  isGamepad=%s  buttons=%d  axes=%d",
					i, tostring(js:getName()), tostring(js:isGamepad()),
					js:getButtonCount(), js:getAxisCount()))
				print("        GUID: " .. tostring(js:getGUID()))
			end
		end
		activeJoystick = pickBestJoystick(joysticks)
		local name    = activeJoystick:getName() or "unknown"
		local isGP    = activeJoystick:isGamepad()
		local profile = ControllerConfig.getProfile(activeJoystick)
		printDebug("🎮 Controller connected: " .. name)
		printDebug("   isGamepad: " .. tostring(isGP) .. "  |  profile: " .. tostring(profile.name))
		if DEBUG_CONTROLLER then
			print("🎮 DEBUG_CONTROLLER ON — press buttons to see their indices")
			print("   Controller: " .. name .. "  |  isGamepad: " .. tostring(isGP))
			print("   GUID: " .. tostring(activeJoystick:getGUID()) .. "  |  raw axes: " .. activeJoystick:getAxisCount())
			if not isGP then
				print("   ⚠️ Not recognized as a gamepad — right stick will use RAW axes 3/4.")
			end
		end
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
	-- Shadow canvas may be invalidated by the GL context resize; force recreation
	local FXshadow = require 'entities.UI.FXshadow'
	FXshadow.resize()
end

function love.update(dt)
	Input.update(activeJoystick)
	sceneManager.update(dt)

	-- Hold AButton → abrir menú de equipo (dispara una sola vez por hold)
	if Input.isDown("AButton") then
		if not aButtonHoldFired then
			aButtonHoldTimer = aButtonHoldTimer + dt
			if aButtonHoldTimer >= MENU_HOLD_THRESHOLD then
				aButtonHoldFired = true
				sceneManager.keypressed("__menuOpen__")
			end
		end
	else
		aButtonHoldTimer = 0
		aButtonHoldFired = false
	end

	if activeJoystick then
		handleGamepadInput(dt)
	end
end

function handleGamepadInput(dt)
	local cc       = ControllerConfig
	local js       = activeJoystick
	local deadzone = cc.getDeadzone(js)

	local leftX = cc.getAxis(js, "horizontal")
	local leftY = cc.getAxis(js, "vertical")

	local moveLeft  = leftX < -deadzone or cc.isDown(js, "dpleft")
	local moveRight = leftX >  deadzone or cc.isDown(js, "dpright")
	local moveUp    = leftY < -deadzone or cc.isDown(js, "dpup")
	local moveDown  = leftY >  deadzone or cc.isDown(js, "dpdown")

	if sceneManager.gamepadInput then
		sceneManager.gamepadInput({
			left     = moveLeft,
			right    = moveRight,
			up       = moveUp,
			down     = moveDown,
			a        = cc.isDown(js, "AButton"),
			b        = cc.isDown(js, "BButton"),
			x        = cc.isDown(js, "XButton"),
			y        = cc.isDown(js, "menuOpen"),
			menuOpen = cc.isDown(js, "menuOpen"),
			start    = cc.isDown(js, "pause"),
			back     = cc.isDown(js, "back"),
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

	CRTDebugMenu.draw()
end

function love.keypressed(key)
	if CRTDebugMenu.keypressed(key) then return end
	if key == "f9" then
		-- Procedural generator self-check across a range of progress values.
		for progress = 0, (Config.MapGen.totalCrew or 12) do
			local ok, err = pcall(MapGenerator.selfCheck, progress)
			if not ok then print("❌ selfCheck FAILED at progress " .. progress .. ": " .. tostring(err)) end
		end
		print("🎲 gen-test complete")
		return
	end
	if Input.is(key, "toggleCRT") then
		crtEnabled = not crtEnabled
	elseif Input.is(key, "fullscreen") then
		local wasFullscreen = love.window.getFullscreen()
		love.window.setFullscreen(not wasFullscreen)
		love.timer.sleep(0.02)
		updateScale()
	elseif Input.is(key, "res1") then
		love.window.setMode(400, 240, {resizable=true, minwidth=400, minheight=240})
		updateScale()
		require('entities.UI.FXshadow').resize()
	elseif Input.is(key, "res2") then
		love.window.setMode(800, 480, {resizable=true, minwidth=400, minheight=240})
		updateScale()
		require('entities.UI.FXshadow').resize()
	elseif Input.is(key, "res3") then
		local currentWidth, currentHeight = love.window.getMode()
		if currentWidth == 800 and currentHeight == 480 then
			love.window.setMode(400, 240, {resizable=true, minwidth=400, minheight=240})
		else
			love.window.setMode(800, 480, {resizable=true, minwidth=400, minheight=240})
		end
		love.timer.sleep(0.02)
		updateScale()
		require('entities.UI.FXshadow').resize()
	end
	-- Scenes handle their own logic
	sceneManager.keypressed(key)
end

function love.keyreleased(key)
	sceneManager.keyreleased(key)
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
	table.insert(joysticks, joystick)
	printDebug("🎮 joystickadded: " .. tostring(joystick:getName())
		.. "  isGamepad=" .. tostring(joystick:isGamepad())
		.. "  GUID=" .. tostring(joystick:getGUID()))
	-- A real gamepad showing up (e.g. the 8BitDo after the iOS accelerometer)
	-- should take over from a virtual/accelerometer joystick.
	if not activeJoystick or (joystick:isGamepad() and not activeJoystick:isGamepad()) then
		activeJoystick = pickBestJoystick(joysticks)
		printDebug("🎮 Active controller: " .. tostring(activeJoystick:getName())
			.. "  isGamepad=" .. tostring(activeJoystick:isGamepad())
			.. "  GUID=" .. tostring(activeJoystick:getGUID()))
	end
end

function love.joystickremoved(joystick)
	for i, j in ipairs(joysticks) do
		if j == joystick then
			table.remove(joysticks, i)
			break
		end
	end

	if activeJoystick == joystick then
		activeJoystick = pickBestJoystick(joysticks) -- prefer a real gamepad
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

function love.wheelmoved(x, y)
	if sceneManager.wheelmoved then
		sceneManager.wheelmoved(x, y)
	end
end