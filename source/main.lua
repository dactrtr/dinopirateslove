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
local canvas -- offscreen render target
local crtEnabled = true

-- Scaling variables
local scale = 1
local offsetX = 0
local offsetY = 0

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
	
	-- Configure scanlines
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
	
	-- Initialize scenes
	sceneManager.init()
	sceneManager.registerScene("title", titleScene)
	sceneManager.registerScene("game", gameScene)
	sceneManager.setCurrentScene("title")
	
	titleScene.load()
	gameScene.load()
end

function updateScale()
	-- Get actual screen dimensions
	local screenWidth = love.graphics.getWidth()
	local screenHeight = love.graphics.getHeight()
	
	-- Calculate scale to fit virtual resolution in the screen
	local scaleX = screenWidth / VIRTUAL_WIDTH
	local scaleY = screenHeight / VIRTUAL_HEIGHT
	
	-- Use the smaller scale to maintain aspect ratio (pillarbox/letterbox)
	scale = math.min(scaleX, scaleY)
	
	-- Calculate offset to center the game
	offsetX = (screenWidth - VIRTUAL_WIDTH * scale) / 2
	offsetY = (screenHeight - VIRTUAL_HEIGHT * scale) / 2
end

function love.resize(w, h)
	-- Recalculate scaling when window is resized
	updateScale()
end

function love.update(dt)
	sceneManager.update(dt)
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
	
	-- Make sure color is reset before drawing
	love.graphics.setColor(1, 1, 1, 1)
	
	if crtEnabled then
		-- Apply CRT effect to the entire scaled output
		crt_effect(function()
			-- Apply scaling and centering inside the CRT effect
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
	elseif key == "f" then
		-- Toggle fullscreen
		love.window.setFullscreen(not love.window.getFullscreen())
	elseif key == "escape" then
		love.event.quit()
	end
	sceneManager.keypressed(key)
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