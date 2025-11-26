local sceneManager = require "sceneManager"
-- local config = require "config"
local titleScene = {
	currentOption = 1,
	options = { "Start Game", "Settings", "Quit" },
	backgroundImage = nil,
	-- Settings menu state
	inSettings = false,
	settingsOption = 1,
	settingsOptions = {
		{name = "CRT Enabled", type = "toggle", setting = "crtEnabled"},
		{name = "Scanlines Opacity", type = "slider", setting = {"scanlines", "opacity"}, min = 0, max = 1, step = 0.05},
		{name = "Scanlines Frequency", type = "slider", setting = {"scanlines", "frequency"}, min = 100, max = 400, step = 10},
		{name = "Scanlines Thickness", type = "slider", setting = {"scanlines", "thickness"}, min = 0.1, max = 2, step = 0.1},
		{name = "CRT Distortion", type = "slider", setting = {"crt", "distortionFactor"}, min = 1.0, max = 1.1, step = 0.01},
		{name = "CRT Feather", type = "slider", setting = {"crt", "feather"}, min = 0, max = 0.1, step = 0.01},
		{name = "Chromatic Aberration", type = "slider", setting = {"chromasep", "radius"}, min = 0, max = 5, step = 0.5},
		{name = "Back", type = "action"}
	}
}

function titleScene.load()
	titleScene.backgroundImage = love.graphics.newImage("assets/images/screens/titlescreen.png")
end

function titleScene.update(dt)
	-- Title scene logic (if needed)
end

function titleScene.draw()
	-- Draw background image
	love.graphics.draw(titleScene.backgroundImage, 0, 0)

	-- Menu options positioning using virtual resolution
	local screenWidth = VIRTUAL_WIDTH
	local screenHeight = VIRTUAL_HEIGHT
	
	if titleScene.inSettings then
		titleScene.drawSettings()
	else
		titleScene.drawMainMenu()
	end

	love.graphics.setColor(1, 1, 1) -- Reset to white
end

function titleScene.drawMainMenu()
	local screenWidth = VIRTUAL_WIDTH
	local screenHeight = VIRTUAL_HEIGHT
	local optionHeight = 30
	local totalOptionsHeight = #titleScene.options * optionHeight
	local startY = screenHeight - totalOptionsHeight - 20  -- 20px margin from bottom
	local leftMargin = 20 -- Left margin for text
	local boxPadding = 8 -- Padding inside the box

	for i, option in ipairs(titleScene.options) do
		local y = startY + (i - 1) * optionHeight
		
		-- Calculate text width for background box
		local font = love.graphics.getFont()
		local textWidth = font:getWidth(option)
		local textHeight = font:getHeight()
		
		-- Draw black background box
		love.graphics.setColor(0, 0, 0, UI_OVERLAY_OPACITY) -- Use global opacity
		love.graphics.rectangle("fill", 
			leftMargin - boxPadding, 
			y - boxPadding, 
			textWidth + boxPadding * 2, 
			textHeight + boxPadding * 2)
		
		-- Draw text
		if i == titleScene.currentOption then
			love.graphics.setColor(1, 1, 0) -- Yellow for selected
		else
			love.graphics.setColor(1, 1, 1) -- White for unselected
		end
		love.graphics.print(option, leftMargin, y)
	end
end

function titleScene.drawSettings()
	local screenWidth = VIRTUAL_WIDTH
	local screenHeight = VIRTUAL_HEIGHT
	local lineHeight = 16
	local startY = 20
	
	-- Draw full-screen black overlay
	love.graphics.setColor(0, 0, 0, UI_OVERLAY_OPACITY)
	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
	
	-- Title
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("SETTINGS", 0, startY, screenWidth, "center")
	
	startY = startY + 30
	
	-- Settings options
	for i, option in ipairs(titleScene.settingsOptions) do
		local y = startY + (i - 1) * lineHeight
		
		if i == titleScene.settingsOption then
			love.graphics.setColor(1, 1, 0) -- Yellow
		else
			love.graphics.setColor(1, 1, 1) -- White
		end
		
		local text = option.name
		if option.type == "toggle" then
			local value = _G[option.setting] and "ON" or "OFF"
			text = text .. ": " .. value
		elseif option.type == "slider" then
			local value = titleScene.getSettingValue(option.setting)
			text = text .. ": " .. string.format("%.2f", value)
		end
		
		love.graphics.printf(text, 20, y, screenWidth - 40, "left")
	end
	
	-- Instructions
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.printf("Use LEFT/RIGHT to adjust", 0, screenHeight - 30, screenWidth, "center")
end

function titleScene.getSettingValue(setting)
	if type(setting) == "table" then
		return moonshinSettings[setting[1]][setting[2]]
	else
		return _G[setting]
	end
end

function titleScene.setSettingValue(setting, value)
	if type(setting) == "table" then
		moonshinSettings[setting[1]][setting[2]] = value
	else
		_G[setting] = value
	end
	applyCRTSettings()
end

function titleScene.keypressed(key)
	if titleScene.inSettings then
		titleScene.handleSettingsInput(key)
	else
		titleScene.handleMainMenuInput(key)
	end
end

function titleScene.handleMainMenuInput(key)
	if key == "down" then
		titleScene.currentOption = titleScene.currentOption + 1
		if titleScene.currentOption > #titleScene.options then 
			titleScene.currentOption = 1 
		end
	elseif key == "up" then
		titleScene.currentOption = titleScene.currentOption - 1
		if titleScene.currentOption < 1 then 
			titleScene.currentOption = #titleScene.options 
		end
	elseif key == "return" or key == "kpenter" then
		if titleScene.currentOption == 1 then
			-- Start transition to game
			sceneManager.startTransition("title", "game", "fade")
		elseif titleScene.currentOption == 2 then
			-- Enter settings
			titleScene.inSettings = true
			titleScene.settingsOption = 1
		elseif titleScene.currentOption == 3 then
			love.event.quit()
		end
	end
end

function titleScene.handleSettingsInput(key)
	local option = titleScene.settingsOptions[titleScene.settingsOption]
	
	if key == "down" then
		titleScene.settingsOption = titleScene.settingsOption + 1
		if titleScene.settingsOption > #titleScene.settingsOptions then 
			titleScene.settingsOption = 1 
		end
	elseif key == "up" then
		titleScene.settingsOption = titleScene.settingsOption - 1
		if titleScene.settingsOption < 1 then 
			titleScene.settingsOption = #titleScene.settingsOptions 
		end
	elseif key == "left" or key == "right" then
		if option.type == "toggle" then
			local currentValue = titleScene.getSettingValue(option.setting)
			titleScene.setSettingValue(option.setting, not currentValue)
		elseif option.type == "slider" then
			local currentValue = titleScene.getSettingValue(option.setting)
			local delta = (key == "right") and option.step or -option.step
			local newValue = math.max(option.min, math.min(option.max, currentValue + delta))
			titleScene.setSettingValue(option.setting, newValue)
		end
	elseif key == "return" or key == "kpenter" or key == "escape" then
		if option.type == "action" or key == "escape" then
			-- Back to main menu
			titleScene.inSettings = false
		end
	end
end

return titleScene