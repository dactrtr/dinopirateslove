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
	
	inSettings = false
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
	
	-- Helper to get frame from index (4 columns: sheet is 720x168, 4×3 frames)
	local function getMenuFrame(idx)
		local cols = 4
		local col = ((idx - 1) % cols) + 1
		local row = math.floor((idx - 1) / cols) + 1
		return titleScene.menuGrid(col, row)
	end

	-- Menu Item animations: Default and Selected states
	-- Sheet layout (col, row):
	-- Row 1: Continue plain(1), Continue styled(2), New Game plain(3), New Game styled(4)
	-- Row 2: Delete save plain(5), Delete save styled(6), Achievements plain(7), Achievements styled(8)
	-- Row 3: Credits plain(9), Credits styled(10), Playground plain(11), Playground styled(12)
	titleScene.menuAnimations = {
		defContinue     = anim8.newAnimation(getMenuFrame(1),  1),
		selContinue     = anim8.newAnimation(getMenuFrame(2),  1),
		defNewGame      = anim8.newAnimation(getMenuFrame(3),  1),
		selNewGame      = anim8.newAnimation(getMenuFrame(4),  1),
		defDeleteGame   = anim8.newAnimation(getMenuFrame(5),  1),
		selDeleteGame   = anim8.newAnimation(getMenuFrame(6),  1),
		defAchievements = anim8.newAnimation(getMenuFrame(7),  1),
		selAchievements = anim8.newAnimation(getMenuFrame(8),  1),
		defCredits      = anim8.newAnimation(getMenuFrame(9),  1),
		selCredits      = anim8.newAnimation(getMenuFrame(10), 1),
		defPlayground   = anim8.newAnimation(getMenuFrame(11), 1),
		selPlayground   = anim8.newAnimation(getMenuFrame(12), 1),
	}

	-- Initialize SaveSystem Backup
	SaveSystem.createOriginalBackup()
	printDebug("✅ Title Scene Assets Loaded")
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
	printDebug("🔍 SaveSystem: Checking '" .. filename .. "' at " .. love.filesystem.getSaveDirectory())
	printDebug("🔍 SaveSystem: info=" .. (info and "TABLE" or "NIL") .. ", saveExists=" .. tostring(saveExists))
	
	if saveExists then
		printDebug("💾 Adding Continue and Delete options")
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
					-- Resume in place: honour the saved player position instead of a
					-- door spawn (computeSpawn skips repositioning when this is set).
					PlayerData.returningInPlace = true
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
				if RunState then RunState.clear() end  -- wipe the in-memory run too
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
			PlayerData.actualLevel = 4
			PlayerData.saveLevel = 7
			PlayerData.health  = PlayerData.maxHealth or 3
			PlayerData.battery = 100
			PlayerData.isGaming   = true
			PlayerData.fromTitle  = true
			-- Procedural: generate a FRESH run graph (stages startId as pending).
			-- Without this, RunState still points at the last room from a prior play
			-- and gameScene.enter() reuses it instead of starting over.
			PlayerData.runCount = 1
			if RunState then RunState.startRun() end
			sceneManager.startTransition("title", "game", "animated", "transitionFall")
		end
	})
	currentY = currentY + spacing

	-- CREDITS
	table.insert(titleScene.menuItems, {
		name = "Credits",
		x = startX, y = currentY,
		defaultAnim = titleScene.menuAnimations.defCredits,
		selectedAnim = titleScene.menuAnimations.selCredits,
		bgState = "achievements",
		action = function()
			printDebug("Viewing credits...")
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

	-- Draw menu items
	if #titleScene.menuItems == 0 then
		love.graphics.print("ERROR: No menu items found", 20, 20)
	end

	for i, item in ipairs(titleScene.menuItems) do
		local anim = (i == titleScene.currentOption) and item.selectedAnim or item.defaultAnim
		if anim then
			anim:draw(titleScene.menuImage, item.x, item.y)
		end
	end

	-- Draw version number
	love.graphics.setColor(0.5, 0.5, 0.5)
	love.graphics.printf(titleScene.version, 0, VIRTUAL_HEIGHT - 20, VIRTUAL_WIDTH - 10, "right")
	love.graphics.setColor(1, 1, 1)
end

function titleScene.keypressed(key)
	if Input.is(key, "up") then
		titleScene.currentOption = titleScene.currentOption - 1
		if titleScene.currentOption < 1 then titleScene.currentOption = #titleScene.menuItems end
		titleScene.updateSelection()
	elseif Input.is(key, "down") then
		titleScene.currentOption = titleScene.currentOption + 1
		if titleScene.currentOption > #titleScene.menuItems then titleScene.currentOption = 1 end
		titleScene.updateSelection()
	elseif Input.is(key, "AButton") then
		local item = titleScene.menuItems[titleScene.currentOption]
		if item and item.action then
			item.action()
		end
	end
end

function titleScene.gamepadInput(input)
	if Input.wasPressed("up") then
		titleScene.currentOption = titleScene.currentOption - 1
		if titleScene.currentOption < 1 then titleScene.currentOption = #titleScene.menuItems end
		titleScene.updateSelection()
	elseif Input.wasPressed("down") then
		titleScene.currentOption = titleScene.currentOption + 1
		if titleScene.currentOption > #titleScene.menuItems then titleScene.currentOption = 1 end
		titleScene.updateSelection()
	elseif Input.wasPressed("AButton") then
		local item = titleScene.menuItems[titleScene.currentOption]
		if item and item.action then
			item.action()
		end
	end
end

return titleScene