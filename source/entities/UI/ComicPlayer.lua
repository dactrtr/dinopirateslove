-- entities/UI/ComicPlayer.lua
-- Love2D port of the Panels cutscene system.
--
-- Usage:
--   ComicPlayer.start(comics["intro"], function()
--       PlayerData.isGaming  = true
--       PlayerData.isCutscene = false
--   end)
--
--   In update:    if ComicPlayer.isActive() then ComicPlayer.update(dt) end
--   In draw:      if ComicPlayer.isActive() then ComicPlayer.draw()    end
--   In keypressed: ComicPlayer.keypressed(key)   (safe to call always)

local ComicPlayer = {}

-- ── Internal state ─────────────────────────────────────────────────────────────
local active      = false
local sequences   = {}
local seqIdx      = 1
local panelIdx    = 1
local onFinish    = nil
local layerStates = {}   -- per-layer animation/typewriter state
local imageCache  = {}   -- path → love.graphics.Image

-- ── Image loader ───────────────────────────────────────────────────────────────
local function tryLoadImage(path)
	if imageCache[path] ~= nil then return imageCache[path] end
	local fullPath = "images/" .. path .. ".png"
	if not love.filesystem.getInfo(fullPath) then
		imageCache[path] = false   -- mark as not found so we don't retry
		return false
	end
	local ok, img = pcall(love.graphics.newImage, fullPath)
	imageCache[path] = ok and img or false
	return imageCache[path]
end

-- ── Navigation helpers ─────────────────────────────────────────────────────────
local function currentSeq()
	return sequences[seqIdx]
end

local function currentPanel()
	local s = currentSeq()
	return s and s.panels and s.panels[panelIdx]
end

-- ── Panel initialisation ───────────────────────────────────────────────────────
local function initPanel()
	layerStates = {}
	local panel = currentPanel()
	if not panel then return end

	for i, layer in ipairs(panel.layers or {}) do
		local state = {
			x          = layer.x or 0,
			y          = layer.y or 0,
			opacity    = layer.opacity or 1,
			typeTimer  = 0,
			typeLen    = 0,          -- current visible character count
			animFrame  = 1,
			animTimer  = 0,
		}

		-- Position / opacity animation
		if layer.animate then
			state.anim = {
				fromX    = state.x,
				fromY    = state.y,
				toX      = layer.animate.x or state.x,
				toY      = layer.animate.y or state.y,
				duration = layer.animate.duration or 500,
				elapsed  = 0,
			}
		end

		-- Typewriter: start at 0 chars; TYPE_ON effect makes it grow with time
		if layer.text then
			if layer.effect and layer.effect.type == "TYPE_ON" then
				state.typeLen = 0
			else
				state.typeLen = #layer.text   -- show full text immediately
			end
		end

		-- Pre-warm image cache (no-op if missing)
		if layer.image then tryLoadImage(layer.image) end

		layerStates[i] = state
	end
end

-- ── Advance to next panel / sequence ──────────────────────────────────────────
local function advance()
	local seq = currentSeq()
	if not seq then return end

	panelIdx = panelIdx + 1
	if panelIdx > #seq.panels then
		seqIdx   = seqIdx + 1
		panelIdx = 1
		if seqIdx > #sequences then
			-- comic finished
			active    = false
			imageCache = {}
			if onFinish then onFinish() end
			return
		end
	end
	initPanel()
end

-- ── Public API ─────────────────────────────────────────────────────────────────

function ComicPlayer.start(comicData, callback)
	if not comicData or #comicData == 0 then
		if callback then callback() end
		return
	end
	active     = true
	sequences  = comicData
	seqIdx     = 1
	panelIdx   = 1
	onFinish   = callback
	imageCache = {}
	initPanel()
end

function ComicPlayer.isActive()
	return active
end

function ComicPlayer.stop()
	active = false
	imageCache = {}
	if onFinish then onFinish() end
	onFinish = nil
end

-- ── Update ─────────────────────────────────────────────────────────────────────

function ComicPlayer.update(dt)
	if not active then return end
	local panel = currentPanel()
	if not panel then return end

	for i, layer in ipairs(panel.layers or {}) do
		local s = layerStates[i]
		if not s then goto continue end

		-- Position animation
		if s.anim then
			local a = s.anim
			a.elapsed = math.min(a.elapsed + dt * 1000, a.duration)
			local t = a.elapsed / a.duration
			-- simple ease-out quad
			t = 1 - (1 - t) * (1 - t)
			s.x = a.fromX + (a.toX - a.fromX) * t
			s.y = a.fromY + (a.toY - a.fromY) * t
		end

		-- Typewriter
		if layer.text and layer.effect and layer.effect.type == "TYPE_ON" then
			local dur = layer.effect.duration or 800
			s.typeTimer = s.typeTimer + dt * 1000
			s.typeLen = math.min(
				math.floor((s.typeTimer / dur) * #layer.text),
				#layer.text
			)
		end

		-- imageTable animation (frame cycling)
		if layer.imageTable and type(layer.imageTable) == "table" then
			local fps = layer.fps or 8
			s.animTimer = s.animTimer + dt
			if s.animTimer >= 1 / fps then
				s.animTimer = s.animTimer - 1 / fps
				s.animFrame = (s.animFrame % #layer.imageTable) + 1
			end
		end

		::continue::
	end
end

-- ── Draw ───────────────────────────────────────────────────────────────────────

function ComicPlayer.draw()
	if not active then return end
	local panel = currentPanel()
	if not panel then return end
	local seq = currentSeq()

	local W = VIRTUAL_WIDTH  or 400
	local H = VIRTUAL_HEIGHT or 240

	-- ── Background ─────────────────────────────────────────────────────────────
	-- White unless the sequence specifies otherwise
	local bg = seq and seq.backgroundColor
	if bg == nil or bg == "white" or (Graphics and bg == Graphics.kColorWhite) then
		love.graphics.setColor(1, 1, 1, 1)
	else
		love.graphics.setColor(0.196, 0.184, 0.161, 1)
	end
	love.graphics.rectangle("fill", 0, 0, W, H)

	-- ── Panel border ───────────────────────────────────────────────────────────
	local margin = (panel.frame and panel.frame.margin)
	             or (seq   and seq.frame   and seq.frame.margin)
	             or 4
	if margin > 0 then
		love.graphics.setColor(0.196, 0.184, 0.161, 1)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", margin, margin,
			W - margin * 2, H - margin * 2)
	end

	-- ── Layers ─────────────────────────────────────────────────────────────────
	-- Language codes that may appear as layer.name for localised variants
	local LANG_NAMES = { en = true, jp = true }
	local currentLang = (Panels and Panels.vars and Panels.vars.lang) or "en"

	for i, layer in ipairs(panel.layers or {}) do
		-- Skip layers whose name is a language code that doesn't match current lang
		if layer.name and LANG_NAMES[layer.name] and layer.name ~= currentLang then
			goto continueLayer
		end

		local s   = layerStates[i] or {}
		local lx  = s.x or layer.x or 0
		local ly  = s.y or layer.y or 0
		local op  = s.opacity or layer.opacity or 1

		love.graphics.setColor(1, 1, 1, op)

		-- Static image
		if layer.image then
			local img = tryLoadImage(layer.image)
			if img then
				love.graphics.draw(img, lx, ly)
			else
				-- Placeholder so layout is visible while assets are missing
				love.graphics.setColor(0.25, 0.25, 0.28, 0.6)
				love.graphics.rectangle("fill", lx, ly, 80, 50)
				love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
				love.graphics.printf(layer.image, lx, ly + 16, 80, "center")
			end

		-- Animated imageTable (array of image paths)
		elseif layer.imageTable and type(layer.imageTable) == "table" then
			local frame = layer.imageTable[s.animFrame or 1]
			if frame then
				local img = tryLoadImage(frame)
				if img then love.graphics.draw(img, lx, ly) end
			end

		-- Text (with optional typewriter)
		elseif layer.text then
			love.graphics.setColor(0.196, 0.184, 0.161, op)
			local visible = layer.text:sub(1, s.typeLen or #layer.text)
			local w = (layer.rect and layer.rect.width)
			       or (W - math.abs(lx) * 2 - 8)
			love.graphics.printf(visible, lx, ly, w)
		end

		::continueLayer::
	end

	-- ── Advance hint ───────────────────────────────────────────────────────────
	local advBtn = seq and seq.advanceControl
	-- advanceControl is a Panels.Input.* value which we map to our Input action name
	-- Default: "menuConfirm" → shows the first key bound to it
	local actionName = (advBtn == "menuConfirm" or advBtn == nil) and "menuConfirm"
	               or advBtn
	local hint = (Input and Input[actionName] and Input[actionName][1]) or "Z"
	love.graphics.setColor(0.196, 0.184, 0.161, 0.55)
	love.graphics.printf("[" .. hint:upper() .. "]",
		0, H - 14, W - (margin + 2), "right")

	love.graphics.setColor(1, 1, 1, 1)
end

-- ── Input ──────────────────────────────────────────────────────────────────────

function ComicPlayer.keypressed(key)
	if not active then return end
	local seq = currentSeq()
	-- advanceControl is a Panels.Input.* constant, which we've mapped to Input keys
	local advBtn = (seq and seq.advanceControl) or "menuConfirm"
	if Input.is(key, advBtn) or Input.is(key, "BButton") or Input.is(key, "AButton") then
		advance()
	end
end

return ComicPlayer
