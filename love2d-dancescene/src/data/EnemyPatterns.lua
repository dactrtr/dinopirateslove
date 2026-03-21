-- src/data/EnemyPatterns.lua
EnemyPatterns = {
    basic = {
        weights     = { arrows = 0.8, aButton = 0.2, bButton = 0.0 },
        style       = "arrow_heavy",
        phaseLength = 10,
    },
    evolve = {
        weights     = { arrows = 0.6, aButton = 0.2, bButton = 0.2 },
        style       = "mixed",
        phaseLength = 10,
    },
    badass = {
        weights     = { arrows = 0.4, aButton = 0.3, bButton = 0.3 },
        style       = "tough",
        phaseLength = 8,
    },
    boss = {
        weights     = { arrows = 0.2, aButton = 0.4, bButton = 0.4 },
        style       = "button_spam",
        phaseLength = 6,
    },
}

-- Picks one button key from a profile's weight table.
-- Returns one of: "leftButton","upButton","rightButton","downButton","aButton","bButton"
function getPatternKey(profile)
    local w    = profile.weights
    local rand = math.random()
    local sum  = w.arrows + w.aButton + w.bButton
    local choice = rand * sum
    if choice < w.arrows then
        local arrows = { "leftButton", "upButton", "rightButton", "downButton" }
        return arrows[math.random(#arrows)]
    elseif choice < w.arrows + w.aButton then
        return "aButton"
    else
        return "bButton"
    end
end
