-- entities/player/sanity.lua
-- Single global sanity ticker — mirrors the fixed Playdate build.
--
-- Playdate history: Player:init() used to create a keyRepeatTimer per Player and
-- never removed it; since a fresh Player is built on every room entry and Noble
-- ticks all timers globally, after visiting N rooms there were N timers draining
-- sanity in parallel (N×). The fix: ONE persistent timer created at boot that
-- targets the live player via a global CurrentPlayer.
--
-- Port equivalent: main.lua calls SanitySystem.update(dt) every frame (the single
-- "timer"), which advances ONE accumulator and ticks once per interval. tick()
-- targets the live player (gameScene.player) and is a no-op before one exists, so
-- sanity drains at 1× regardless of how many rooms were visited.

local SanitySystem = {}

local function cfg()
    return (Config and Config.Sanity) or {}
end

-- Config.Sanity.tickInterval is in MILLISECONDS (Playdate convention); update()
-- accumulates dt in seconds, so convert.
local function tickInterval()
    return (cfg().tickInterval or 2000) / 1000
end

-- One accumulator for the whole session. Never reset per room (that was the N×
-- bug); it just keeps counting from boot.
local tickTimer = 0

-- The live player, equivalent to Playdate's global CurrentPlayer. Persists across
-- scenes (dances, cutscenes), so sanity keeps ticking there too, like Playdate.
local function livePlayer()
    local sceneManager = require 'sceneManager'
    local gs = sceneManager.getScene("game")
    return gs and gs.player or nil
end

function SanitySystem.update(dt)
    local interval = tickInterval()
    tickTimer = tickTimer + dt
    if tickTimer >= interval then
        tickTimer = tickTimer - interval
        SanitySystem.tick()
    end
end

function SanitySystem.tick()
    -- No-op before any player exists (title screen, etc.), matching Playdate's
    -- `if not CurrentPlayer then return end`.
    local player = livePlayer()
    if not player then return end

    local c = cfg()
    local mult = c.baseLoss or c.lossMultiplier or 1
    local lastSanity = PlayerData.sanity
    local hasLamp = PlayerData.items and PlayerData.items.hasLamp == true
    local dark    = PlayerData.isInDarkness == true

    -- ── Lower sanity (mirrors Playdate checkSanityGlobal) ────────────────────
    -- With no lamp the dark is total → drain regardless of battery; with a lamp
    -- it depends on the charge level.
    if dark and not hasLamp then
        PlayerData.sanity = PlayerData.sanity - ((c.lossLowBattery or 2) * mult)
    elseif dark and PlayerData.battery < (c.batteryThresholdLow or 20) then
        PlayerData.sanity = PlayerData.sanity - ((c.lossLowBattery or 2) * mult)
    elseif dark and PlayerData.battery < (c.batteryThresholdMid or 40) then
        PlayerData.sanity = PlayerData.sanity - ((c.lossMidBattery or 1) * mult)
    end

    -- ── Sanity just reached zero → game over ─────────────────────────────────
    -- sanityCounter is preserved (keeps scaling difficulty). Death is gated by
    -- isGaming, like Playdate's `if p.isAlive and PlayerData.isGaming`.
    if PlayerData.sanity <= 0 and lastSanity > 0 then
        PlayerData.sanityCounter = PlayerData.sanityCounter + 1
        PlayerData.sanity = 0
        printDebug("💀 Sanity hit 0 (count: " .. PlayerData.sanityCounter .. ")")
        if PlayerData.isGaming == true then
            local collisions = require 'entities.player.collisions'
            collisions.dead(player, "sanity")
        end
    end

    -- ── Raise sanity: in the light, or in the dark with a well-charged lamp ──
    if (not dark) or (hasLamp and PlayerData.battery > (c.batteryThresholdHigh or 50)) then
        PlayerData.sanity = PlayerData.sanity + ((c.gainHighBattery or 2) * mult)
    end

    -- ── Clamp 0–100 ──────────────────────────────────────────────────────────
    PlayerData.sanity = math.max(0, math.min(c.max or 100, PlayerData.sanity))
end

-- ── Manual focus ability (costs 20 sanity) ───────────────────────────────────
function SanitySystem.focus()
    local cost = cfg().focusCost or 20
    if PlayerData.sanity > cost then
        PlayerData.sanity = PlayerData.sanity - cost
        PlayerData.isFocused = true
    end
end

function SanitySystem.deFocus()
    PlayerData.isFocused = false
end

return SanitySystem
