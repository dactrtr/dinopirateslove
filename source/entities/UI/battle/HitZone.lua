-- entities/UI/battle/HitZone.lua
local anim8 = require 'libraries/anim8'

HitZone = {}
HitZone.__index = HitZone

function HitZone.new(x, y, w, h)
    local self = setmetatable({ x=x, y=y, w=w, h=h }, HitZone)
    self.image = love.graphics.newImage('assets/images/ui/battle/hitzone-table-10-40.png')
    local g    = anim8.newGrid(w, h, self.image:getWidth(), self.image:getHeight())
    self.anim  = anim8.newAnimation(g('1-8', 1), 0.06)
    return self
end

local function aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and
           ay < by + bh and ay + ah > by
end

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

function HitZone:update(dt)
    self.anim:update(dt)
end

function HitZone:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    self.anim:draw(self.image, self.x * scale, self.y * scale, 0, scale, scale)
end
