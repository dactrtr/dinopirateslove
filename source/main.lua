local moonshine = require "libraries/moonshine"
local sceneManager = require "sceneManager"
local titleScene = require "scenes/titleScene"
local gameScene = require "scenes/gameScene"
-- local config = require "config"
local PlayerData = require 'assets/data/PlayerDataTables'
local crt_effect
local font
local canvas -- offscreen render target
local crtEnabled = true

function love.load()
	love.window.setMode(VIRTUAL_WIDTH * 2, VIRTUAL_HEIGHT * 2, { vsync = 1 }) -- real resolution is 800x480
	love.graphics.setDefaultFilter("nearest", "nearest") -- avoid blurry scaling
	
	font = love.graphics.newFont(20)
	love.graphics.setFont(font)

	canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT) -- offscreen canvas for virtual resolution
	
	-- Configure CRT effect with moonshine
	crt_effect = moonshine(moonshine.effects.scanlines)
		.chain(moonshine.effects.crt)
		.chain(moonshine.effects.glow)
	
	-- Configure scanlines
	crt_effect.scanlines.width = 1
	crt_effect.scanlines.frequency = 240
	crt_effect.scanlines.phase = 1
	crt_effect.scanlines.thickness = 1
	crt_effect.scanlines.opacity = 0.5
	
	-- Configure CRT distortion
	crt_effect.crt.distortionFactor = {1.06, 1.065}
	crt_effect.crt.scaleFactor = {1, 1}
	crt_effect.crt.feather = 0.02
	
	-- Configure glow
	crt_effect.glow.strength = 1.0
	crt_effect.glow.min_luma = 0.7
	
	-- Initialize scenes
	sceneManager.init()
	sceneManager.registerScene("title", titleScene)
	sceneManager.registerScene("game", gameScene)
	sceneManager.setCurrentScene("game")
	
	titleScene.load()
	gameScene.load()
end

function love.update(dt)
	sceneManager.update(dt)
end

function love.draw()
	-- Render everything to the canvas first
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	sceneManager.draw()
	love.graphics.setCanvas()

	if crtEnabled then
		-- Draw the canvas with CRT effect
		crt_effect(function()
			love.graphics.push()
			love.graphics.scale(2, 2)
			love.graphics.draw(canvas, 0, 0)
			love.graphics.pop()
		end)
	else
		-- Draw the canvas without CRT effect
		love.graphics.push()
		love.graphics.scale(2, 2)
		love.graphics.draw(canvas, 0, 0)
		love.graphics.pop()
	end
end

function love.keypressed(key)
	if key == "q" then
		crtEnabled = not crtEnabled
	end
	sceneManager.keypressed(key)
end