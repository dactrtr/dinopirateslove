-- entities/UI/cockpit/CockpitRadar.lua
-- Port of the Playdate CockpitRadar sprite to LÖVE 2D.
-- Draws an 8×5 dot-matrix display where dots flicker on/off.

local CockpitRadar = {}

local COLS        = 8
local ROWS        = 5
local APPEAR_RATE = 0.04
local FADE_RATE   = 0.03

-- Dot geometry (fits inside 80×60 with 1 px border; inner area 76×56 px)
-- 8 cols × 4px + 7 gaps × 4px = 60 → 8 px horizontal padding each side
-- 5 rows × 8px + 4 gaps × 4px = 56 → 0 px vertical padding
local DOT_W = 4
local DOT_H = 8
local GAP_X = 4
local GAP_Y = 4
local PAD_X = 8
local PAD_Y = 0

function CockpitRadar.new(x, y, w, h)
    local self = {
        x    = x,
        y    = y,
        rw   = w,
        rh   = h,
        dots = {},
    }

    for row = 1, ROWS do
        self.dots[row] = {}
        for col = 1, COLS do
            self.dots[row][col] = math.random() < 0.3
        end
    end

    return self
end

function CockpitRadar:update(dt)
    for row = 1, ROWS do
        for col = 1, COLS do
            if self.dots[row][col] then
                if math.random() < FADE_RATE   then self.dots[row][col] = false end
            else
                if math.random() < APPEAR_RATE then self.dots[row][col] = true  end
            end
        end
    end
end

function CockpitRadar:draw()
    -- White background + border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.rw, self.rh)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", self.x, self.y, self.rw, self.rh)

    -- Dots
    local startX = self.x + 2 + PAD_X
    local startY = self.y + 2 + PAD_Y

    love.graphics.setColor(0, 0, 0, 1)
    for row = 1, ROWS do
        for col = 1, COLS do
            if self.dots[row][col] then
                local dx = startX + (col - 1) * (DOT_W + GAP_X)
                local dy = startY + (row - 1) * (DOT_H + GAP_Y)
                love.graphics.rectangle("fill", dx, dy, DOT_W, DOT_H)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Kept for API symmetry
function CockpitRadar:remove() end

return CockpitRadar
