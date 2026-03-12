-- entities/UI/FXshadow.lua
-- Darkness overlay using multiply blend (Love2D port of Playdate FXshadow)
--
-- Two-layer lighting (matches Playdate):
--   Layer 1 (ambient)      : canvas fill, brightness = 1 - ambientDark
--   Layer 2 (primary zone) : cone or circle, brightness = 1 - lightAmount
--   Layer 3 (focused spot) : small circle at player, brightness = 1 - lightSourceAmount
--
-- Multiply blend: white(1) = no darkening, black(0) = full dark.
-- Playdate dither 0=transparent=bright  →  Love2D value 1.0
-- Playdate dither 1=opaque=dark         →  Love2D value 0.0

local FXshadow = {}

-- Dark colour (#322F29) used instead of pure black in the multiply canvas.
-- Lerps towards white(1) at full brightness so mid-values keep the warm tint.
local DARK_R, DARK_G, DARK_B = 0.196, 0.184, 0.161
local function darkColor(t)  -- t: 0=dark, 1=white
	return DARK_R + (1 - DARK_R) * t,
	       DARK_G + (1 - DARK_G) * t,
	       DARK_B + (1 - DARK_B) * t
end

local shadowCanvas = nil
local dirty = true

local prev = {
	battery = -1, direction = "", x = -1, y = -1,
	lsm = -1, globalLight = -1, showCone = false,
	lightAmount = -1, lightSourceAmount = -1, ambientDark = -1
}

local function ensureCanvas()
	if not shadowCanvas then
		shadowCanvas = love.graphics.newCanvas(400, 240)
	end
end

function FXshadow.markDirty()
	dirty = true
end

-- Call this when the window is resized: canvas contents may be lost.
function FXshadow.resize()
	shadowCanvas = nil  -- forces ensureCanvas() to recreate it next frame
	dirty = true
	-- Reset prev so change-detection doesn't short-circuit the next refresh
	for k in pairs(prev) do prev[k] = -1 end
	prev.direction = ""
	prev.showCone  = false
end

-- Compute lighting parameters with smooth linear interpolation.
-- Returns: maskSize, lightAmount, lightSourceSize, lightSourceAmount
--   lightAmount/lightSourceAmount: 0=bright zone, 1=dark zone  (zoneBright = 1 - value)
local function computeLightParams(globalLightAmount, lsm)
	local baseSize = 80

	if not PlayerData.items.hasLamp then
		-- No lamp: small dim circle, no cone
		return 30 * lsm, 0.85, 12, 0.7
	end

	local battery = PlayerData.battery * 2  -- scale 0–100 → 0–200

	-- t: 0 = dead battery, 1 = battery at or above 80% (160 scaled)
	-- Above 160 is treated as full (t=1 = no dimming at all)
	local t = math.max(0, math.min(1, battery / 160))

	-- All parameters lerp smoothly from dead (t=0) to full (t=1)
	local maskSize          = baseSize * lsm * (0.5 + 0.5 * t)   -- 40–80 (scaled)
	local lightAmount       = 1.0 - t                              -- 0=bright at full, 1=dark at dead
	local lightSourceSize   = math.floor(15 + 20 * t)             -- 15–35
	local lightSourceAmount = 0.9 * (1.0 - t)                     -- 0=bright at full, 0.9=dim at dead

	return maskSize, lightAmount, lightSourceSize, lightSourceAmount
end

-- Builds the Playdate-matching 8-point directional cone vertex list.
-- d = forward reach, h = lateral spread factor.
-- For left/down, d is negated on the relevant axis in the caller.
local function buildConeVertices(ix, iy, dir, d, h)
	if dir == "left" or dir == "right" then
		local s = (dir == "left") and -1 or 1
		return {
			ix,             iy,
			ix + s*d,       iy - 4*h,
			ix + s*1.1*d,   iy - 3.5*h,
			ix + s*1.2*d,   iy - 2*h,
			ix + s*1.25*d,  iy,
			ix + s*1.2*d,   iy + 2*h,
			ix + s*1.1*d,   iy + 3.5*h,
			ix + s*d,       iy + 4*h,
			ix,             iy,
		}
	else  -- up / down
		local s = (dir == "down") and 1 or -1
		return {
			ix,             iy,
			ix - 4*h,       iy + s*d,
			ix - 3.5*h,     iy + s*1.1*d,
			ix - 2*h,       iy + s*1.2*d,
			ix,             iy + s*1.25*d,
			ix + 2*h,       iy + s*1.2*d,
			ix + 3.5*h,     iy + s*1.1*d,
			ix + 4*h,       iy + s*d,
			ix,             iy,
		}
	end
end

FXshadow.buildConeVertices = buildConeVertices  -- keep for external access if needed

function FXshadow.refresh(player, globalLightAmount)
	ensureCanvas()

	local battery  = PlayerData.battery * 2
	local dir      = PlayerData.direction
	local lsm      = PlayerData.isTiny and 0.5 or 1.0
	local burst    = PlayerData.showLightCone and PlayerData.items.hasLamp

	local maskSize, lightAmount, lightSourceSize, lightSourceAmount =
		computeLightParams(globalLightAmount, lsm)

	-- Flashlight burst: override zone/spot to maximum brightness
	local d, h = 90, 8
	if burst then
		d, h = 200, 12
		lightAmount       = 0
		lightSourceAmount = 0
	end

	-- Change detection
	if not dirty and
	   prev.battery           == battery           and
	   prev.direction         == dir               and
	   prev.x                 == player.x          and
	   prev.y                 == player.y          and
	   prev.lsm               == lsm               and
	   prev.globalLight       == globalLightAmount  and
	   prev.showCone          == burst              and
	   prev.lightAmount       == lightAmount        and
	   prev.lightSourceAmount == lightSourceAmount  then
		return
	end

	dirty = false
	prev.battery           = battery
	prev.direction         = dir
	prev.x                 = player.x
	prev.y                 = player.y
	prev.lsm               = lsm
	prev.globalLight       = globalLightAmount
	prev.showCone          = burst
	prev.lightAmount       = lightAmount
	prev.lightSourceAmount = lightSourceAmount

	-- player.x/y is the sprite center (anim8 draws with origin offset)
	local cx = player.x
	local cy = player.y

	local prevCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(shadowCanvas)
	love.graphics.setBlendMode("alpha")

	-- === Layer 1: Ambient fill ===
	-- globalLightAmount: 0=no ambient (dark room), 1=full ambient (bright room)
	-- Canvas value = ambient brightness in multiply blend (0=black=dark, 1=white=no effect)
	local ambR, ambG, ambB = darkColor(globalLightAmount)
	love.graphics.clear(ambR, ambG, ambB, 1)

	-- === Layer 2: Primary light zone (cone forward, circle when idle/no lamp) ===
	-- zoneBright = 1 - lightAmount, clamped to never be BELOW the ambient
	-- (otherwise the zone would draw darker than the background → visible black shape)
	local zoneBright = math.max(1.0 - lightAmount, globalLightAmount)
	love.graphics.setColor(darkColor(zoneBright))

	local hasLamp = PlayerData.items.hasLamp
	if dir == "idle" or dir == "" or not hasLamp then
		love.graphics.circle("fill", cx, cy, maskSize)
	else
		local verts = buildConeVertices(cx, cy, dir, d, h)
		love.graphics.polygon("fill", verts)
		love.graphics.circle("fill", cx, cy, maskSize * 0.3)
	end

	-- === Layer 3: Focused spot (small bright circle at player position) ===
	-- Also clamped to ambient minimum so it never darkens the scene
	local spotBright = math.max(1.0 - lightSourceAmount, globalLightAmount)
	love.graphics.setColor(darkColor(spotBright))

	local spotRadius = lightSourceSize - (dir == "idle" and 0 or 8)
	local offX = (dir == "left") and -18 or 0
	love.graphics.circle("fill", cx + offX, cy, spotRadius)

	-- Restore previous canvas (critical: avoids breaking Moonshine pipeline)
	love.graphics.setCanvas(prevCanvas)
	love.graphics.setColor(1, 1, 1, 1)
end

function FXshadow.draw(player, globalLightAmount)
	if not PlayerData.isInDarkness then return end
	FXshadow.refresh(player, globalLightAmount)

	-- Multiply blend with "premultiplied" alphamode (required by LÖVE 11 for multiply)
	love.graphics.setBlendMode("multiply", "premultiplied")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(shadowCanvas, 0, 0)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1, 1)
end

return FXshadow
