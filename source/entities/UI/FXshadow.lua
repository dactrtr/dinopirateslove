-- entities/UI/FXshadow.lua
-- Darkness overlay using multiply blend as documented in PLAYER_SYSTEMS.md
--
-- Technique: canvas filled with grey (dark level); white circle cut at player pos.
-- Final draw uses multiply blend: canvas_grey * scene = dark, canvas_white * scene = normal.

local FXshadow = {}

local shadowCanvas = nil
local dirty = true

local prev = {
	battery = -1, direction = "", x = -1, y = -1,
	lightSizeMulti = -1, globalLight = -1, showCone = false, lightAmount = -1
}

local function ensureCanvas()
	if not shadowCanvas then
		shadowCanvas = love.graphics.newCanvas(400, 240)
	end
end

function FXshadow.markDirty()
	dirty = true
end

-- Returns lightAmount (0=bright, 1=fully dark) based on battery tiers from PLAYER_SYSTEMS.md
local function computeLightAmount(globalLightAmount)
	if not PlayerData.items.hasLamp then
		return 1.0  -- no lamp: maximum darkness
	end

	local battery = PlayerData.battery * 2  -- ×2 scale: 0–200

	if     battery > 160 then return globalLightAmount
	elseif battery > 120 then return math.max(globalLightAmount, 0.2)
	elseif battery > 80  then return math.max(globalLightAmount, 0.5)
	elseif battery > 40  then return math.max(globalLightAmount, 0.7)
	elseif battery > 0   then return math.max(globalLightAmount, 0.9)
	else                       return 1.0
	end
end

-- Builds the 9-point directional cone vertex table centered at (cx, cy)
function FXshadow.buildConeVertices(cx, cy, dir, length)
	local hw = length * 0.4  -- half-width of cone
	if dir == "right" then
		return { cx, cy,
		         cx+length,   cy-hw,     cx+length,   cy-hw*0.5,
		         cx+length*1.2, cy,
		         cx+length,   cy+hw*0.5, cx+length,   cy+hw,
		         cx, cy }
	elseif dir == "left" then
		return { cx, cy,
		         cx-length,   cy-hw,     cx-length,   cy-hw*0.5,
		         cx-length*1.2, cy,
		         cx-length,   cy+hw*0.5, cx-length,   cy+hw,
		         cx, cy }
	elseif dir == "up" then
		return { cx, cy,
		         cx-hw,   cy-length,     cx-hw*0.5, cy-length,
		         cx,      cy-length*1.2,
		         cx+hw*0.5, cy-length,   cx+hw,     cy-length,
		         cx, cy }
	else  -- down
		return { cx, cy,
		         cx-hw,   cy+length,     cx-hw*0.5, cy+length,
		         cx,      cy+length*1.2,
		         cx+hw*0.5, cy+length,   cx+hw,     cy+length,
		         cx, cy }
	end
end

function FXshadow.refresh(player, globalLightAmount)
	ensureCanvas()

	local battery     = PlayerData.battery * 2
	local dir         = PlayerData.direction
	local lsm         = PlayerData.isTiny and 0.5 or 1.0
	local cone        = PlayerData.showLightCone and PlayerData.items.hasLamp
	local lightAmount = computeLightAmount(globalLightAmount)

	-- Skip redraw when nothing changed
	if not dirty and
	   prev.battery     == battery       and
	   prev.direction   == dir           and
	   prev.x           == player.x      and
	   prev.y           == player.y      and
	   prev.lightSizeMulti == lsm        and
	   prev.globalLight == globalLightAmount and
	   prev.showCone    == cone          and
	   prev.lightAmount == lightAmount   then
		return
	end

	dirty = false
	prev.battery      = battery
	prev.direction    = dir
	prev.x            = player.x
	prev.y            = player.y
	prev.lightSizeMulti = lsm
	prev.globalLight  = globalLightAmount
	prev.showCone     = cone
	prev.lightAmount  = lightAmount

	-- player.x / player.y IS the sprite center
	-- (anim8 draws with ox = spriteWidth/2, oy = spriteHeight/2)
	local cx = player.x
	local cy = player.y

	-- Light radius (scales with tiny mode)
	local baseRadius = PlayerData.items.hasLamp and 80 or 25
	local radius     = baseRadius * lsm

	-- Canvas background brightness for multiply blend:
	--   lightAmount=0 → baseDark=1 → white canvas → multiply has no effect (bright room)
	--   lightAmount=1 → baseDark=0 → black canvas → multiply = fully dark
	local baseDark = 1.0 - lightAmount

	-- Save the currently active canvas (may be Moonshine's virtual canvas)
	-- so we can restore it after drawing to shadowCanvas
	local prevCanvas = love.graphics.getCanvas()

	love.graphics.setCanvas(shadowCanvas)

	-- Fill canvas with flat grey (darkness level) — clear bypasses blend mode
	love.graphics.clear(baseDark, baseDark, baseDark, 1)

	-- Draw white light area: white * scene = scene (no darkening)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1, 1)

	if cone then
		local verts = FXshadow.buildConeVertices(cx, cy, dir, radius * 2)
		love.graphics.polygon("fill", verts)
		-- Always add a base circle so there is light directly around player
		love.graphics.circle("fill", cx, cy, radius * 0.5)
	else
		love.graphics.circle("fill", cx, cy, radius)
	end

	-- Restore previous canvas (critical: avoids breaking Moonshine's virtual canvas pipeline)
	love.graphics.setCanvas(prevCanvas)
	love.graphics.setColor(1, 1, 1, 1)
end

function FXshadow.draw(player, globalLightAmount)
	if not PlayerData.isInDarkness then return end
	FXshadow.refresh(player, globalLightAmount)

	-- Multiply blend with "premultiplied" alphamode (required by LÖVE 11 for multiply)
	-- Canvas alpha is always 1.0 (clear + white circles), so premultiplied = non-premultiplied
	love.graphics.setBlendMode("multiply", "premultiplied")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(shadowCanvas, 0, 0)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1, 1)
end

return FXshadow
