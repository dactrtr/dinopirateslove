-- scenes/DeadScene.lua
-- Game-over screen for the roguelike death loop. Shown when the player is caught
-- (loses the Dance fight), loses their mind (sanity), or falls into the void.
-- Two options: Retry (starts a FRESH run via RunState) and Exit (back to title).
-- Ported from the Playdate DeadScene to the LÖVE scene pattern (plain table).
--
-- Set PlayerData.deathCause before transitioning here:
--   "caught" (default) → "they caught you"
--   "sanity"           → "you lost your mind"
--   "void"             → "you fell into the void"

local sceneManager = require "sceneManager"

local deadScene = {}

-- Death-cause → message (default falls back to "caught").
local MESSAGES = {
	caught = "they caught you",
	sanity = "you lost your mind",
	void   = "you fell into the void",
}

-- Module-local state (reset in enter())
local currentOption = 1
local font          = nil
local bg            = nil   -- optional dead-screen art (assets/images/screens/dead-screen.png)
local transitioning = false

-- Menu items. Action runs on AButton. `defaultSelect` is highlighted on enter
-- (Exit, matching the Playdate original — discourages accidental retries).
local menuItems = {
	{
		name = "Retry",
		action = function()
			-- A death starts a brand-new run: bump the counter and regenerate the
			-- graph (stages startId as pending), then enter the game fresh.
			PlayerData.runCount = (PlayerData.runCount or 0) + 1
			PlayerData.deathCause = nil
			PlayerData.health  = PlayerData.maxHealth or 3
			PlayerData.healthPoints = (Config and Config.Player and Config.Player.maxHealth) or 3
			PlayerData.battery = 100
			PlayerData.isGaming = true
			if RunState then RunState.startRun() end
			sceneManager.startTransition("dead", "game", "fade")
		end
	},
	{
		name = "Exit",
		action = function()
			PlayerData.deathCause = nil
			sceneManager.startTransition("dead", "title", "fade")
		end
	},
}

function deadScene.load()
	font = love.graphics.newFont(12)
	-- Dead-screen art is optional; draw a black background + text when absent.
	local ok, img = pcall(love.graphics.newImage, "assets/images/screens/dead-screen.png")
	if ok and img then
		img:setFilter("nearest", "nearest")
		bg = img
	else
		bg = nil
	end
	printDebug("✅ Dead Scene Assets Loaded")
end

function deadScene.enter()
	PlayerData.isGaming = false
	transitioning = false
	-- Default selection: Exit (index 2), matching the Playdate original.
	currentOption = 2
end

local function activate(item)
	if transitioning then return end
	if item and item.action then
		transitioning = true
		item.action()
	end
end

function deadScene.update(dt)
end

function deadScene.draw()
	love.graphics.clear(0, 0, 0, 1)
	local prevFont = love.graphics.getFont()
	if font then love.graphics.setFont(font) end

	if bg then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(bg, 0, 0)
	end

	-- Death message, bottom-left (matches Playdate placement).
	local msg = MESSAGES[PlayerData.deathCause or "caught"] or MESSAGES.caught
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(msg, 6, VIRTUAL_HEIGHT - 20)

	-- Menu, centered.
	local startY = 110
	local spacing = 22
	for i, item in ipairs(menuItems) do
		local selected = (i == currentOption)
		if selected then
			love.graphics.setColor(1, 1, 0, 1)
			love.graphics.printf("> " .. item.name .. " <", 0, startY + (i - 1) * spacing, VIRTUAL_WIDTH, "center")
		else
			love.graphics.setColor(0.7, 0.7, 0.7, 1)
			love.graphics.printf(item.name, 0, startY + (i - 1) * spacing, VIRTUAL_WIDTH, "center")
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
	if prevFont then love.graphics.setFont(prevFont) end
end

local function moveSelection(delta)
	currentOption = currentOption + delta
	if currentOption < 1 then currentOption = #menuItems end
	if currentOption > #menuItems then currentOption = 1 end
end

function deadScene.keypressed(key)
	if Input.is(key, "up") then
		moveSelection(-1)
	elseif Input.is(key, "down") then
		moveSelection(1)
	elseif Input.is(key, "AButton") then
		activate(menuItems[currentOption])
	end
end

function deadScene.gamepadInput(input)
	if Input.wasPressed("up") then
		moveSelection(-1)
	elseif Input.wasPressed("down") then
		moveSelection(1)
	elseif Input.wasPressed("AButton") then
		activate(menuItems[currentOption])
	end
end

return deadScene
