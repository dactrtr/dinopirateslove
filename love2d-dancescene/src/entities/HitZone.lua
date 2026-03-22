-- src/entities/HitZone.lua
-- Fixed rect on the left side of the battle screen.
-- Detects which ButtonPress entities are currently overlapping it.

HitZone = {}
HitZone.__index = HitZone

function HitZone.new(x, y, w, h)
    return setmetatable({ x=x, y=y, w=w, h=h }, HitZone)
end

-- AABB intersection
local function aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and
           ay < by + bh and ay + ah > by
end

-- buttons: table of ButtonPress instances
-- Returns list of overlapping, non-hit buttons.
function HitZone:overlapping(buttons)
    local result = {}
    for _, btn in ipairs(buttons) do
        if not btn.isHit then
            local bx, by, bw, bh = btn:getBounds()
            if aabbOverlap(self.x, self.y, self.w, self.h, bx, by, bw, bh) then
                result[#result + 1] = btn
            end
        end
    end
    return result
end

function HitZone:draw(scale)
    scale = scale or 2
    love.graphics.setColor(0.2, 0.8, 0.2, 0.5)
    love.graphics.rectangle("fill", self.x * scale, self.y * scale, self.w * scale, self.h * scale)
    love.graphics.setColor(1, 1, 1)
end
