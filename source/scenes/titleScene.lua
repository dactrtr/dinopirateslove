local sceneManager = require "sceneManager"
local anim8 = require 'libraries/anim8'
local SaveSystem = require 'SaveSystem'
-- PlayerData is now global from main.lua

local titleScene = {
	currentOption = 1,
	menuItems = {},
	
	background = {
		image = nil,
		animation = nil,
		grid = nil,
		currentState = "newGame"
	},
	
	-- Version number
	version = "v1.0.0",
	
	-- Settings menu state (preserving this part from previous implementation if needed, 
	-- but focusing on the Playdate port as requested)
	inSettings = false,
	settingsOption = 1,
	settingsOptions = {
		{name = "CRT Enabled", type = "toggle", setting = "crtEnabled"},
		{name = "Scanlines Opacity", type = "slider", setting = {"scanlines", "opacity"}, min = 0, max = 1, step = 0.05},
		{name = "Back", type = "action"}
	}
}

-- RoomTranslate helper as requested
local function RoomTranslate(roomNumber)
	-- In this Love2D setup, we might need a different way to map room numbers to levels
	-- For now, we'll try to find the level in levelsLDTK
	if not levelsLDTK then return nil end
	
	for i, level in ipairs(levelsLDTK) do
		if level.customFields and level.customFields.roomNumber == roomNumber then
			return i -- Return the index for gameScene.setFloor
		end
	end
	return nil
end

function titleScene.load()
	-- Load Background Animation
	titleScene.background.image = love.graphics.newImage("assets/images/screens/title-background-table-400-240.png")
	titleScene.background.grid = anim8.newGrid(400, 240, titleScene.background.image:getWidth(), titleScene.background.image:getHeight())
	
	-- Helper to get frame from index (assuming 4 columns)
	local function getBGFrame(idx)
		local col = ((idx - 1) % 4) + 1
		local row = math.floor((idx - 1) / 4) + 1
		return titleScene.background.grid(col, row)
	end

	-- Background states: single frames as defined in Playdate code
	titleScene.background.animations = {
		continue = anim8.newAnimation(getBGFrame(1), 1),
		deleteGame = anim8.newAnimation(getBGFrame(3), 1),
		newGame = anim8.newAnimation(getBGFrame(6), 1),
		achievements = anim8.newAnimation(getBGFrame(8), 1)
	}
	titleScene.background.animation = titleScene.background.animations.newGame

	-- Load Menu Items sprite
	titleScene.menuImage = love.graphics.newImage("assets/images/screens/menuTitle-table-180-56.png")
	titleScene.menuGrid = anim8.newGrid(180, 56, titleScene.menuImage:getWidth(), titleScene.menuImage:getHeight())
	
	-- Helper to get frame from index (assuming 3 columns for 540x168)
	local function getMenuFrame(idx)
		local cols = 3
		local col = ((idx - 1) % cols) + 1
		local row = math.floor((idx - 1) / cols) + 1
		return titleScene.menuGrid(col, row)
	end

	-- Menu Item animations: Default and Selected states
	titleScene.menuAnimations = {
		defContinue = anim8.newAnimation(getMenuFrame(1), 1),
		selContinue = anim8.newAnimation(getMenuFrame(2), 1),
		defNewGame = anim8.newAnimation(getMenuFrame(3), 1),
		selNewGame = anim8.newAnimation(getMenuFrame(4), 1),
		defDeleteGame = anim8.newAnimation(getMenuFrame(5), 1),
		selDeleteGame = anim8.newAnimation(getMenuFrame(6), 1),
		defAchievements = anim8.newAnimation(getMenuFrame(7), 1),
		selAchievements = anim8.newAnimation(getMenuFrame(8), 1),
		defPlayground = anim8.newAnimation(getMenuFrame(9), 1),
		selPlayground = anim8.newAnimation(getMenuFrame(9), 1) 
	}

	-- Initialize SaveSystem Backup
	SaveSystem.createOriginalBackup()
	print("✅ Title Scene Assets Loaded")
end

function titleScene.enter()
	titleScene.inSettings = false
	PlayerData.isGaming = false
	
	-- Re-build menu items based on save existence
	titleScene.menuItems = {}
	local startY = 120
	local startX = 88
	local spacing = 24 -- Adjusted spacing
	local currentY = startY

	-- Check for save
	local filename = "gameState.lua"
	local info = love.filesystem.getInfo(filename)
	local saveExists = info ~= nil
	print("🔍 SaveSystem: Checking '" .. filename .. "' at " .. love.filesystem.getSaveDirectory())
	print("🔍 SaveSystem: info=" .. (info and "TABLE" or "NIL") .. ", saveExists=" .. tostring(saveExists))
	
	if saveExists then
		print("💾 Adding Continue and Delete options")
		-- CONTINUE
		table.insert(titleScene.menuItems, {
			name = "Continue",
			x = startX, y = currentY,
			defaultAnim = titleScene.menuAnimations.defContinue,
			selectedAnim = titleScene.menuAnimations.selContinue,
			bgState = "continue",
			action = function()
				local success, savedLevel = SaveSystem.load()
				if success then
					sceneManager.startTransition("title", "game", "animated", "transitionFall")
				end
			end
		})
		currentY = currentY + spacing
		
		-- DELETE SAVE
		table.insert(titleScene.menuItems, {
			name = "Delete Save",
			x = startX, y = currentY,
			defaultAnim = titleScene.menuAnimations.defDeleteGame,
			selectedAnim = titleScene.menuAnimations.selDeleteGame,
			bgState = "deleteGame",
			action = function()
				SaveSystem.delete()
				titleScene.enter() -- Refresh menu
			end
		})
		currentY = currentY + spacing
	end

	-- NEW GAME
	table.insert(titleScene.menuItems, {
		name = "New Game",
		x = startX, y = currentY,
		defaultAnim = titleScene.menuAnimations.defNewGame,
		selectedAnim = titleScene.menuAnimations.selNewGame,
		bgState = "newGame",
		action = function()
			SaveSystem.reset()
			sceneManager.startTransition("title", "game", "animated", "transitionFall")
		end
	})
	currentY = currentY + spacing

	-- ACHIEVEMENTS
	table.insert(titleScene.menuItems, {
		name = "Achievements",
		x = startX, y = currentY,
		defaultAnim = titleScene.menuAnimations.defAchievements,
		selectedAnim = titleScene.menuAnimations.selAchievements,
		bgState = "achievements",
		action = function()
			-- Add achievements view logic here if implemented
			print("Viewing achievements...")
		end
	})
	currentY = currentY + spacing

	-- SETTINGS
	table.insert(titleScene.menuItems, {
		name = "Settings",
		x = startX, y = currentY,
		defaultAnim = titleScene.menuAnimations.defAchievements,
		selectedAnim = titleScene.menuAnimations.selAchievements,
		bgState = "achievements",
		action = function()
			titleScene.inSettings = true
			titleScene.settingsOption = 1
		end
	})
	currentY = currentY + spacing

	-- PLAYGROUND (Debug)
	if DEBUG_MODE or true then -- Showing for now
		table.insert(titleScene.menuItems, {
			name = "Playground",
			x = startX, y = currentY,
			defaultAnim = titleScene.menuAnimations.defPlayground,
			selectedAnim = titleScene.menuAnimations.selPlayground,
			bgState = "achievements", -- Reusing bg state
			action = function()
				PlayerData.playerSpawn.x = 200
				PlayerData.playerSpawn.y = 200
				sceneManager.startTransition("title", "game", "animated", "transitionFall")
			end
		})
		currentY = currentY + spacing
	end

	titleScene.currentOption = 1
	titleScene.updateSelection()
end

function titleScene.updateSelection()
	local item = titleScene.menuItems[titleScene.currentOption]
	if item then
		titleScene.background.animation = titleScene.background.animations[item.bgState] or titleScene.background.animations.newGame
	end
end

function titleScene.update(dt)
	-- Update background animation
	if titleScene.background.animation then
		titleScene.background.animation:update(dt)
	end
end

function titleScene.draw()
	-- Draw background
	if titleScene.background.animation then
		titleScene.background.animation:draw(titleScene.background.image, 0, 0)
	end

	if titleScene.inSettings then
		-- Draw Settings Menu
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle("fill", 50, 40, 300, 160)
		love.graphics.setColor(1, 1, 1)
		love.graphics.rectangle("line", 50, 40, 300, 160)
		
		love.graphics.printf("SETTINGS", 0, 50, VIRTUAL_WIDTH, "center")
		
		local startY = 80
		for i, option in ipairs(titleScene.settingsOptions) do
			local y = startY + (i-1) * 25
			
			if i == titleScene.settingsOption then
				love.graphics.setColor(1, 1, 0)
				love.graphics.print("> " .. option.name, 70, y)
			else
				love.graphics.setColor(1, 1, 1)
				love.graphics.print("  " .. option.name, 70, y)
			end
			
			-- Draw Value
			if option.type == "toggle" then
				local val = _G[option.setting]
				local text = val and "ON" or "OFF"
				love.graphics.print(text, 250, y)
			elseif option.type == "slider" then
				local val = moonshinSettings[option.setting[1]][option.setting[2]]
				love.graphics.print(string.format("%.0f%%", val * 100), 250, y)
			end
		end
	else
		-- Draw menu items
		if #titleScene.menuItems == 0 then
			love.graphics.print("ERROR: No menu items found", 20, 20)
		end

		for i, item in ipairs(titleScene.menuItems) do
			local anim = (i == titleScene.currentOption) and item.selectedAnim or item.defaultAnim
			if anim then
				-- Draw sprite at position
				anim:draw(titleScene.menuImage, item.x, item.y)
			end
		end
		
		-- Draw version number
		love.graphics.setColor(0.5, 0.5, 0.5)
		love.graphics.printf(titleScene.version, 0, VIRTUAL_HEIGHT - 20, VIRTUAL_WIDTH - 10, "right")
		love.graphics.setColor(1, 1, 1)
	end
end

function titleScene.keypressed(key)
	if titleScene.inSettings then
		if key == "up" then
			titleScene.settingsOption = titleScene.settingsOption - 1
			if titleScene.settingsOption < 1 then titleScene.settingsOption = #titleScene.settingsOptions end
		elseif key == "down" then
			titleScene.settingsOption = titleScene.settingsOption + 1
			if titleScene.settingsOption > #titleScene.settingsOptions then titleScene.settingsOption = 1 end
		elseif key == "left" or key == "right" then
			local option = titleScene.settingsOptions[titleScene.settingsOption]
			if option.type == "slider" then
				local current = moonshinSettings[option.setting[1]][option.setting[2]]
				local change = (key == "right" and 1 or -1) * option.step
				current = current + change
				if current > option.max then current = option.max end
				if current < option.min then current = option.min end
				moonshinSettings[option.setting[1]][option.setting[2]] = current
				applyCRTSettings()
			end
		elseif key == "return" or key == "kpenter" or key == "z" or key == "a" then
			local option = titleScene.settingsOptions[titleScene.settingsOption]
			if option.type == "action" and option.name == "Back" then
				titleScene.inSettings = false
			elseif option.type == "toggle" then
				_G[option.setting] = not _G[option.setting]
			end
		elseif key == "escape" or key == "x" or key == "b" then
			titleScene.inSettings = false
		end
	else
		if key == "up" then
			titleScene.currentOption = titleScene.currentOption - 1
			if titleScene.currentOption < 1 then titleScene.currentOption = #titleScene.menuItems end
			titleScene.updateSelection()
		elseif key == "down" then
			titleScene.currentOption = titleScene.currentOption + 1
			if titleScene.currentOption > #titleScene.menuItems then titleScene.currentOption = 1 end
			titleScene.updateSelection()
		elseif key == "return" or key == "kpenter" or key == "z" or key == "a" then
			local item = titleScene.menuItems[titleScene.currentOption]
			if item and item.action then
				item.action()
			end
		end
	end
end

return titleScene