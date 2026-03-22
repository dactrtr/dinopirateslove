-- tests/test_hitzone.lua
package.path = package.path .. ";../src/entities/?.lua"
love = { timer = { getTime = function() return 0 end } }

require("ButtonPress")
require("HitZone")

local function makeBtn(x, key)
    local btn = ButtonPress.new(16, x, function() return key end)
    return btn
end

describe("HitZone", function()
    local hz = HitZone.new(30, 100, 20, 40)  -- x, y, w, h (logical)

    it("detects a button inside the zone", function()
        local btn = makeBtn(35, "aButton")  -- x=35, inside zone x=30..50
        local hits = hz:overlapping({ btn })
        assert.equals(1, #hits)
        assert.equals(btn, hits[1])
    end)

    it("does not detect a button outside the zone", function()
        local btn = makeBtn(200, "aButton")
        local hits = hz:overlapping({ btn })
        assert.equals(0, #hits)
    end)

    it("ignores hit buttons", function()
        local btn = makeBtn(35, "aButton")
        btn:hit()
        local hits = hz:overlapping({ btn })
        assert.equals(0, #hits)
    end)

    it("detects multiple buttons in zone", function()
        local b1 = makeBtn(33, "aButton")
        local b2 = makeBtn(38, "leftButton")
        local hits = hz:overlapping({ b1, b2 })
        assert.equals(2, #hits)
    end)
end)
