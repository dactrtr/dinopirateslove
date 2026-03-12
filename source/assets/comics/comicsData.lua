-- assets/comics/comicsData.lua
-- Loads all comic definitions and exposes the global `comics` table.
--
-- Comic data files reference Panels.* constants from the Playdate library.
-- We define compatibility stubs here before loading them so the files work
-- unchanged in Love2D.

-- ── Panels compatibility stubs ────────────────────────────────────────────────
Panels = Panels or {
	ScrollType = {
		AUTO   = "auto",
		MANUAL = "manual",
	},
	ScrollDirection = {
		NONE          = "none",
		TOP_DOWN      = "topDown",
		LEFT_TO_RIGHT = "leftToRight",
		RIGHT_TO_LEFT = "rightToLeft",
	},
	-- Panels.Input values map directly to our Input action names so
	-- ComicPlayer can call  Input.is(key, seq.advanceControl)  unchanged.
	Input = {
		A    = "menuConfirm",
		B    = "menuBack",
		UP   = "up",
		DOWN = "down",
	},
	Effect = {
		TYPE_ON = "TYPE_ON",
	},
	-- Language variable used by Utilities.renderLangPanel
	vars = { lang = "en" },
}

-- ── Utilities stub (subset used by comic data files) ──────────────────────────
-- renderLangPanel: stores the current-language filter on the panel so
-- ComicPlayer.draw() can skip layers whose name is the wrong language.
Utilities = Utilities or {}
Utilities.renderLangPanel = function(panel, offset)
	-- no-op: ComicPlayer handles language-named layers natively
end

-- Graphics.kColorWhite stub (used as backgroundColor in some comics)
-- Graphics may not be initialized yet when this file is loaded, so create the table if needed
Graphics = Graphics or {}
if not Graphics.kColorWhite then
	Graphics.kColorWhite = "white"
end

-- ── Load comic data files (each sets a global variable) ─────────────────────
local function loadComicFile(path)
	local chunk, err = love.filesystem.load(path)
	if chunk then
		chunk()
	else
		printDebug("⚠️ ComicsData: could not load " .. path .. " – " .. tostring(err))
	end
end

loadComicFile("assets/comics/intro.lua")
loadComicFile("assets/comics/pick-the-device.lua")

-- ── Comics index ──────────────────────────────────────────────────────────────
comics = {
	["intro"]           = intro,
	["pick-the-device"] = pickDevice,
}

printDebug("📖 Comics loaded: " .. tostring(#comics) .. " entries")
