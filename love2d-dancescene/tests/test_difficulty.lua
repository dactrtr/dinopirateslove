-- tests/test_difficulty.lua
package.path = package.path .. ";../src/?.lua;../src/data/?.lua"

-- Stub globals that DanceScene references but we don't need for these tests
PlayerData = require("PlayerData")

-- Inline the two functions under test (copy verbatim from DanceScene.lua)
local function determineDifficultyUpgrade(sanityCounter, powerLevel, calories)
    local sanity   = sanityCounter or 0
    local power    = powerLevel    or 0
    local cal      = calories      or 0
    local sanityNorm   = math.max(0, math.min(1, sanity / 100))
    local powerNorm    = math.max(0, math.min(1, power  / 20))
    local caloriesNorm = math.max(0, math.min(1, cal    / 500))
    local score = sanityNorm * 0.35 + powerNorm * 0.45 + caloriesNorm * 0.20
    return math.max(0, math.min(100, score * 100))
end

local function determineEnemyType(pwr)
    if pwr >= 1  and pwr <= 5  then return "basic"  end
    if pwr >= 6  and pwr <= 12 then return "evolve" end
    if pwr >= 13 and pwr <= 19 then return "badass" end
    if pwr == 20               then return "boss"   end
    return "basic"
end

describe("determineDifficultyUpgrade", function()
    it("returns 0 when all inputs are 0", function()
        assert.equals(0, determineDifficultyUpgrade(0, 0, 0))
    end)
    it("returns 100 when all inputs are at max", function()
        assert.equals(100, determineDifficultyUpgrade(100, 20, 500))
    end)
    it("clamps output to [0, 100]", function()
        local p = determineDifficultyUpgrade(999, 999, 999)
        assert.is_true(p >= 0 and p <= 100)
    end)
    it("powerLevel has the largest weight (0.45)", function()
        local powerOnly = determineDifficultyUpgrade(0, 20, 0)
        assert.equals(45, powerOnly)
    end)
end)

describe("determineEnemyType", function()
    it("returns basic for powerLevel 1-5",  function()
        for i = 1, 5 do assert.equals("basic",  determineEnemyType(i)) end
    end)
    it("returns evolve for powerLevel 6-12", function()
        for i = 6, 12 do assert.equals("evolve", determineEnemyType(i)) end
    end)
    it("returns badass for powerLevel 13-19", function()
        for i = 13, 19 do assert.equals("badass", determineEnemyType(i)) end
    end)
    it("returns boss for powerLevel 20", function()
        assert.equals("boss", determineEnemyType(20))
    end)
    it("falls back to basic for out-of-range values", function()
        assert.equals("basic", determineEnemyType(0))
        assert.equals("basic", determineEnemyType(21))
    end)
end)
