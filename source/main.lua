local moonshine = require "libraries/moonshine"
local sceneManager = require "sceneManager"
local titleScene = require "scenes/titleScene"
local gameScene = require "scenes/gameScene"

local crt_effect
local font

function love.load()
	love.window.setMode(400, 240, { fullscreen = false, resizable = false, vsync = 1 })
	font = love.graphics.newFont(20)
	love.graphics.setFont(font)
	
	-- Configure CRT effect with moonshine
	crt_effect = moonshine(moonshine.effects.scanlines)
		.chain(moonshine.effects.crt)
		.chain(moonshine.effects.glow)
	
	-- CRT effect parameters
	-- Scanlines configuration
	crt_effect.scanlines.width = 2        -- Scanline thickness
	crt_effect.scanlines.frequency = 240  -- Scanlines frequency (higher = more lines)
	crt_effect.scanlines.phase = 0        -- Phase offset
	crt_effect.scanlines.thickness = 1    -- Line thickness
	crt_effect.scanlines.opacity = 0.4    -- Scanlines opacity (0-1)
	
	-- CRT distortion configuration
	crt_effect.crt.distortionFactor = {1.06, 1.065}  -- Screen curvature [x, y]
	crt_effect.crt.scaleFactor = {1, 1}               -- Scale factor [x, y]
	crt_effect.crt.feather = 0.02                     -- Edge softness
	
	-- Glow effect configuration
	crt_effect.glow.strength = 1.0        -- Glow intensity
	crt_effect.glow.min_luma = 0.7        -- Minimum brightness threshold for glow effect
	
	-- Initialize scenes
	sceneManager.init()
	sceneManager.registerScene("title", titleScene)
	sceneManager.registerScene("game", gameScene)
	sceneManager.setCurrentScene("title")
	
	-- Initialize each scene
	titleScene.load()
	gameScene.load()
end

function love.update(dt)
	sceneManager.update(dt)
end

function love.draw()
	crt_effect(function()
		sceneManager.draw()
	end)
end

function love.keypressed(key)
	sceneManager.keypressed(key)
end