-- tests/test_button_press.lua
package.path = package.path .. ";../src/entities/?.lua;../src/data/?.lua"

-- Stub love2d globals for unit testing outside of love
love = { timer = { getTime = function() return 0 end } }

require("EnemyPatterns")  -- for getPatternKey
require("ButtonPress")

describe("ButtonPress", function()
    it("starts at the given startX position", function()
        local btn = ButtonPress.new(16, 400, function() return "aButton" end)
        assert.equals(400, btn.x)
    end)

    it("has a valid buttonKey after creation", function()
        local btn = ButtonPress.new(16, 400, function() return "leftButton" end)
        assert.equals("leftButton", btn.buttonKey)
    end)

    it("moves left when updated with no delay set", function()
        local btn = ButtonPress.new(16, 400, function() return "aButton" end)
        -- no movementDelay call → delay is 0, movement starts immediately
        btn:update(0.1)
        assert.is_true(btn.x < 400)
    end)

    it("does not move before movementDelay expires", function()
        local btn = ButtonPress.new(16, 400, function() return "aButton" end)
        btn:movementDelay(5000)  -- large delay
        btn:update(0.1)
        assert.equals(400, btn.x)
    end)

    it("is marked hit after hit() is called", function()
        local btn = ButtonPress.new(16, 400, function() return "aButton" end)
        assert.is_false(btn.isHit)
        btn:hit()
        assert.is_true(btn.isHit)
    end)
end)
