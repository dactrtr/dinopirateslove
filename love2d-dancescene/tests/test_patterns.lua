-- tests/test_patterns.lua
package.path = package.path .. ";../src/data/?.lua"
require("EnemyPatterns")

describe("getPatternKey", function()
    it("always returns a valid button key", function()
        local valid = {
            leftButton=true, rightButton=true, upButton=true, downButton=true,
            aButton=true, bButton=true
        }
        math.randomseed(42)
        for _ = 1, 200 do
            local key = getPatternKey(EnemyPatterns.basic)
            assert.is_true(valid[key] ~= nil, "invalid key: " .. tostring(key))
        end
    end)

    it("boss profile has a/b appear in at least 60% of 1000 rolls", function()
        math.randomseed(12345)
        local abCount = 0
        for _ = 1, 1000 do
            local k = getPatternKey(EnemyPatterns.boss)
            if k == "aButton" or k == "bButton" then abCount = abCount + 1 end
        end
        assert.is_true(abCount >= 600, "expected >=60% a/b for boss, got " .. abCount)
    end)

    it("basic profile returns arrows at ~80% rate", function()
        math.randomseed(99)
        local arrowCount = 0
        local arrows = { leftButton=true, rightButton=true, upButton=true, downButton=true }
        for _ = 1, 1000 do
            local k = getPatternKey(EnemyPatterns.basic)
            if arrows[k] then arrowCount = arrowCount + 1 end
        end
        -- Allow ±5% tolerance
        assert.is_true(arrowCount >= 750 and arrowCount <= 850,
            "expected ~80% arrows for basic, got " .. arrowCount)
    end)
end)
