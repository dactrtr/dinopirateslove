-- entities/player/sanity.lua
-- Timer-based sanity system (tick every 2s, mirrors Playdate keyRepeatTimer).
-- Call SanitySystem.update(dt) each frame from gameScene.update().

local SanitySystem = {}

local TICK_INTERVAL = 2.0   -- seconds between each check
local SANITY_LOSS   = 1     -- base multiplier

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

    -- ── Lower sanity: darkness + low battery ─────────────────────────────────
    if PlayerData.isInDarkness then
        if PlayerData.battery < 20 then
            PlayerData.sanity = PlayerData.sanity - (2 * SANITY_LOSS)
        elseif PlayerData.battery < 40 then
            PlayerData.sanity = PlayerData.sanity - SANITY_LOSS
        end
    end

    -- ── Detect hitting 0 for the first time this cycle ────────────────────────
    if PlayerData.sanity <= 0 and lastSanity > 0 then
        PlayerData.sanityCounter = PlayerData.sanityCounter + 1
        PlayerData.sanity = 0
        printDebug("💀 Sanity hit 0 (count: " .. PlayerData.sanityCounter .. ")")
    end

    -- ── Raise sanity: high battery OR not in darkness ─────────────────────────
    if PlayerData.battery > 50 or not PlayerData.isInDarkness then
        PlayerData.sanity = PlayerData.sanity + (2 * SANITY_LOSS)
    end

    -- ── Clamp 0–100 ──────────────────────────────────────────────────────────
    PlayerData.sanity = math.max(0, math.min(100, PlayerData.sanity))
end

-- ── Manual focus ability (costs 20 sanity) ───────────────────────────────────
function SanitySystem.focus()
    if PlayerData.sanity > 20 then
        PlayerData.sanity = PlayerData.sanity - 20
        PlayerData.isFocused = true
    end
end

function SanitySystem.deFocus()
    PlayerData.isFocused = false
end

return SanitySystem
