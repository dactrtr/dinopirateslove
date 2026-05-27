-- entities/UI/cockpit/CockpitBars.lua
-- Port of the Playdate CockpitBars sprite to LÖVE 2D.
-- Draws a panel of horizontal activity bars that randomly fluctuate.

local CockpitBars = {}

local BAR_COUNT   = 5
local LERP_SPEED  = 0.06
local CHANGE_RATE = 0.03  -- probability per frame each bar picks a new target

function CockpitBars.new(x, y, w, h)
    local self = {
        x    = x,
        y    = y,
        bw   = w,
        bh   = h,
        bars = {},
    }

    for i = 1, BAR_COUNT do
        local v = math.random()
        self.bars[i] = { current = v, target = v }
    end

    return self
end

function CockpitBars:update(dt)
    for _, bar in ipairs(self.bars) do
        if math.random() < CHANGE_RATE then
            bar.target = math.random()
        end
        bar.current = bar.current + (bar.target - bar.current) * LERP_SPEED
    end
end

function CockpitBars:draw()
    local n    = #self.bars
    local gap  = 2
    local rowH = math.floor((self.bh - 2 - gap * (n - 1)) / n)

    -- White face
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.bw, self.bh)

    -- Border
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", self.x, self.y, self.bw, self.bh)

    -- Bars
    love.graphics.setColor(0, 0, 0, 1)
    for i, bar in ipairs(self.bars) do
        local by   = self.y + 1 + (i - 1) * (rowH + gap)
        local barW = math.max(1, math.floor(bar.current * (self.bw - 4)))
        love.graphics.rectangle("fill", self.x + 2, by, barW, rowH)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Kept for API symmetry
function CockpitBars:remove() end

return CockpitBars
