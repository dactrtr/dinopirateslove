local moonshine = require "libraries/moonshine"
local crt_effect
local titleScene = {}
local currentOption = 1
local options = { "Start Game", "Quit" }
local font, backgroundImage

function love.load()
	love.window.setMode(400, 240, { fullscreen = true, resizable = false, vsync = 1 })
	font = love.graphics.newFont(20)
	love.graphics.setFont(font)
	backgroundImage = love.graphics.newImage("assets/screens/test.png")
	
	-- Configure CRT effect with moonshine
	crt_effect = moonshine(moonshine.effects.scanlines)
		.chain(moonshine.effects.crt)
		.chain(moonshine.effects.glow)
	
	-- CRT effect parameters
	-- Scanlines configuration
	crt_effect.scanlines.width = 1        -- Scanline thickness
	crt_effect.scanlines.frequency = 440  -- Scanlines frequency (higher = more lines)
	crt_effect.scanlines.phase = 0        -- Phase offset
	crt_effect.scanlines.thickness = 1    -- Line thickness
	crt_effect.scanlines.opacity = 0.4    -- Scanlines opacity (0-1)
	
	-- CRT distortion configuration
	crt_effect.crt.distortionFactor = {1.06, 1.065}  -- Screen curvature [x, y]
	crt_effect.crt.scaleFactor = {1, 1}               -- Scale factor [x, y]
	crt_effect.crt.feather = 0.02                     -- Edge softness
	
	-- Glow effect configuration
	crt_effect.glow.strength = 1.6        -- Glow intensity
	crt_effect.glow.min_luma = 0.7        -- Minimum brightness threshold for glow effect
end

function love.update(dt)
end

function love.draw()
	crt_effect(function()
		-- Everything drawn here will have the CRT effect applied
		love.graphics.draw(backgroundImage, 0, 0, 0,
			love.graphics.getWidth() / backgroundImage:getWidth(),
			love.graphics.getHeight() / backgroundImage:getHeight()
		)
		
		-- Draw menu options
		for i, option in ipairs(options) do
			if i == currentOption then
				love.graphics.setColor(1, 1, 0)  -- Yellow for selected option
			else
				love.graphics.setColor(1, 1, 1)  -- White for unselected options
			end
			love.graphics.printf(option, 0, 100 + i * 30, love.graphics.getWidth(), "center")
		end
		love.graphics.setColor(1, 1, 1)  -- Reset color to white
	end)
end

function love.keypressed(key)
	if key == "down" then
		currentOption = currentOption + 1
		if currentOption > #options then currentOption = 1 end
	elseif key == "up" then
		currentOption = currentOption - 1
		if currentOption < 1 then currentOption = #options end
	elseif key == "return" or key == "kpenter" then
		if currentOption == 1 then
			print("Start Game selected")
			-- Add your game start logic here
		elseif currentOption == 2 then
			love.event.quit()
		end
	end
end