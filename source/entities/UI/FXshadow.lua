-- entities/UI/FXshadow.lua
-- Darkness overlay with battery-tiered light radius and optional directional cone

local FXshadow = {}

local shadowCanvas = nil
local dirty = true

-- Previous state for dirty-flag comparison
local prev = {
	battery = -1, direction = "", x = -1, y = -1,
	lightSizeMulti = -1, globalLight = -1, showCone = false
}

local function ensureCanvas()
	if not shadowCanvas then
		shadowCanvas = love.graphics.newCanvas(400, 240)
	end
end

function FXshadow.markDirty()
	dirty = true
end

function FXshadow.buildConeVertices(cx, cy, dir, length)
	local hw = length * 0.4
	if dir == "right" then
		return {cx, cy, cx+length, cy-hw, cx+length, cy-hw*0.5, cx+length*1.2, cy,
		        cx+length, cy+hw*0.5, cx+length, cy+hw, cx, cy}
	elseif dir == "left" then
		return {cx, cy, cx-length, cy-hw, cx-length, cy-hw*0.5, cx-length*1.2, cy,
		        cx-length, cy+hw*0.5, cx-length, cy+hw, cx, cy}
	elseif dir == "up" then
		return {cx, cy, cx-hw, cy-length, cx-hw*0.5, cy-length, cx, cy-length*1.2,
		        cx+hw*0.5, cy-length, cx+hw, cy-length, cx, cy}
	else -- down
		return {cx, cy, cx-hw, cy+length, cx-hw*0.5, cy+length, cx, cy+length*1.2,
		        cx+hw*0.5, cy+length, cx+hw, cy+length, cx, cy}
	end
end

function FXshadow.refresh(player, globalLightAmount)
	ensureCanvas()

	local battery  = PlayerData.battery * 2  -- scale ×2 so 100 battery = 200
	local dir      = PlayerData.direction
	local lsm      = PlayerData.isTiny and 0.5 or 1.0
	local cone     = PlayerData.showLightCone and PlayerData.items.hasLamp

	-- Skip redraw when nothing changed
	if not dirty and
	   prev.battery == battery and prev.direction == dir and
	   prev.x == player.x and prev.y == player.y and
	   prev.lightSizeMulti == lsm and prev.globalLight == globalLightAmount and
	   prev.showCone == cone then
		return
	end

	dirty = false
	prev.battery       = battery
	prev.direction     = dir
	prev.x             = player.x
	prev.y             = player.y
	prev.lightSizeMulti = lsm
	prev.globalLight   = globalLightAmount
	prev.showCone      = cone

	-- Determine darkness intensity based on battery tiers
	local lightAmount
	if PlayerData.items.hasLamp then
		if     battery > 160 then lightAmount = globalLightAmount
		elseif battery > 120 then lightAmount = math.max(globalLightAmount, 0.2)
		elseif battery > 80  then lightAmount = math.max(globalLightAmount, 0.5)
		elseif battery > 40  then lightAmount = math.max(globalLightAmount, 0.7)
		elseif battery > 0   then lightAmount = math.max(globalLightAmount, 0.9)
		else                      lightAmount = 1.0
		end
	else
		lightAmount = 1.0
	end

	-- Light circle radius
	local baseRadius = PlayerData.items.hasLamp and 80 or 25
	local radius = baseRadius * lsm * (1 - lightAmount * 0.3)

	-- Render shadow canvas
	love.graphics.setCanvas(shadowCanvas)
	love.graphics.clear(0, 0, 0, 0)

	-- Dark overlay
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(0, 0, 0, lightAmount)
	love.graphics.rectangle("fill", 0, 0, 400, 240)

	-- Cut transparent light hole using subtract blend
	love.graphics.setBlendMode("subtract")
	love.graphics.setColor(lightAmount, lightAmount, lightAmount, lightAmount)

	local cx = player.x + player.spriteWidth / 2
	local cy = player.y + player.spriteHeight / 2

	if cone then
		local verts = FXshadow.buildConeVertices(cx, cy, dir, radius * 2)
		love.graphics.polygon("fill", verts)
		-- Base circle always present even with cone
		love.graphics.circle("fill", cx, cy, radius * 0.5)
	else
		love.graphics.circle("fill", cx, cy, radius)
	end

	love.graphics.setBlendMode("alpha")
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1, 1)
end

function FXshadow.draw(player, globalLightAmount)
	if not PlayerData.isInDarkness then return end
	FXshadow.refresh(player, globalLightAmount)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(shadowCanvas, 0, 0)
end

return FXshadow
