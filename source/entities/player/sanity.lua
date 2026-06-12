-- entities/player/sanity.lua
-- Timer-based sanity system (tick every 2s, mirrors Playdate keyRepeatTimer).
-- Call SanitySystem.update(dt) each frame from gameScene.update().

local SanitySystem = {}

local cfg = Config and Config.Sanity or {}
-- Config.Sanity.tickInterval is in MILLISECONDS (Playdate convention); update()
-- accumulates dt in seconds, so convert. Without this, the tick fired every
-- ~2000 seconds (33 min) instead of every 2s and sanity never drained.
local TICK_INTERVAL = (cfg.tickInterval or 2000) / 1000
local SANITY_LOSS   = cfg.lossMultiplier or 1

local tickTimer = 0

function SanitySystem.reset()
    tickTimer = 0
end

function SanitySystem.update(dt)
    if not PlayerData.isGaming then return end

    tickTimer = tickTimer + dt
    if tickTimer >= TICK_INTERVAL then
        tickTimer = tickTimer - TICK_INTERVAL
        SanitySystem.tick()
    end
end

function SanitySystem.tick()
    local lastSanity = PlayerData.sanity
    local hasLamp = PlayerData.items and PlayerData.items.hasLamp == true
    local dark    = PlayerData.isInDarkness == true

    -- ── Lower sanity (mirrors Playdate sanityCheck) ──────────────────────────
    -- With no lamp the dark is total → drain regardless of battery; with a lamp
    -- it depends on the charge level.
    if dark and not hasLamp then
        PlayerData.sanity = PlayerData.sanity - ((cfg.lossLowBattery or 2) * SANITY_LOSS)
    elseif dark and PlayerData.battery < (cfg.batteryThresholdLow or 20) then
        PlayerData.sanity = PlayerData.sanity - ((cfg.lossLowBattery or 2) * SANITY_LOSS)
    elseif dark and PlayerData.battery < (cfg.batteryThresholdMid or 40) then
        PlayerData.sanity = PlayerData.sanity - ((cfg.lossMidBattery or 1) * SANITY_LOSS)
    end

    -- ── Detect hitting 0 for the first time this cycle ────────────────────────
    if PlayerData.sanity <= 0 and lastSanity > 0 then
        PlayerData.sanityCounter = PlayerData.sanityCounter + 1
        PlayerData.sanity = 0
        printDebug("💀 Sanity hit 0 (count: " .. PlayerData.sanityCounter .. ")")
    end

    -- ── Raise sanity: in the light, or in the dark with a well-charged lamp ──
    if (not dark) or (hasLamp and PlayerData.battery > (cfg.batteryThresholdHigh or 50)) then
        PlayerData.sanity = PlayerData.sanity + ((cfg.gainHighBattery or 2) * SANITY_LOSS)
    end

    -- ── Clamp 0–100 ──────────────────────────────────────────────────────────
    PlayerData.sanity = math.max(0, math.min(100, PlayerData.sanity))
end

-- ── Manual focus ability (costs 20 sanity) ───────────────────────────────────
function SanitySystem.focus()
    local cost = cfg.focusCost or 20
    if PlayerData.sanity > cost then
        PlayerData.sanity = PlayerData.sanity - cost
        PlayerData.isFocused = true
    end
end

function SanitySystem.deFocus()
    PlayerData.isFocused = false
end

return SanitySystem
