-- entities/UI/cockpit/CockpitIndicators.lua
-- Port of the Playdate CockpitIndicators sprite to LÖVE 2D.
-- Draws a row of progress circles (sequence position) and a fail bar,
-- pinned to the top of the 400×240 canvas.

local CockpitIndicators = {}

-- Fixed layout matching the Playdate original (top strip 400×28)
local STRIP_X  = 0
local STRIP_Y  = 0
local STRIP_W  = 400
local STRIP_H  = 28

function CockpitIndicators.new()
    local self = {
        filled   = 0,
        total    = 4,
        failFill = 0,
    }
    return self
end

function CockpitIndicators:setData(filled, total, failFill)
    self.filled   = filled
    self.total    = total
    self.failFill = failFill
end

function CockpitIndicators:update(dt)
    -- static display; no per-frame work needed
end

function CockpitIndicators:draw()
    local n          = self.total
    local circleR    = 4
    local circleD    = circleR * 2
    local circleGap  = 4
    local rowW       = n * circleD + (n - 1) * circleGap
    local startX     = math.floor(200 - rowW / 2) + circleR
    local circleY    = STRIP_Y + 8

    love.graphics.setColor(0, 0, 0, 1)
    for i = 1, n do
        local cx = startX + (i - 1) * (circleD + circleGap)
        if i <= self.filled then
            love.graphics.circle("fill", cx, circleY, circleR)
        else
            love.graphics.circle("line", cx, circleY, circleR)
        end
    end

    -- Fail bar
    local barY      = STRIP_Y + 18
    local barH      = 5
    local barMargin = 40
    local barTotalW = STRIP_W - barMargin * 2
    local barFillW  = math.floor(math.min(barTotalW, barTotalW * self.failFill))

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", barMargin, barY, barTotalW, barH)
    if barFillW > 0 then
        love.graphics.rectangle("fill", barMargin, barY, barFillW, barH)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Kept for API symmetry
function CockpitIndicators:remove() end

return CockpitIndicators
