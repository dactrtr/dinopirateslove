-- entities/UI/cockpit/CockpitButton.lua
-- Port of the Playdate CockpitButton sprite to LÖVE 2D.
-- A plain Lua table that draws a labelled 3D-raised button rectangle.

local CockpitButton = {}

-- Default font used for button labels (loaded lazily so love.graphics is ready)
local labelFont = nil
local function getLabelFont()
    if not labelFont then
        -- Try the shinonome bitmap font used elsewhere in the project; fall back to default
        local ok, f = pcall(love.graphics.newFont, 'assets/fonts/shinonome.ttf', 8)
        if ok then
            labelFont = f
        else
            labelFont = love.graphics.newFont(8)
        end
    end
    return labelFont
end

function CockpitButton.new(x, y, w, h, label)
    local self = {
        x     = x,
        y     = y,
        w     = w,
        h     = h,
        label = label,
    }
    return self
end

-- Returns true when the pointer (px, py) is inside this button's rect.
-- x, y are the button's top-left corner (matching how we draw it).
function CockpitButton:isHovered(px, py)
    return px >= self.x and px <= self.x + self.w
       and py >= self.y and py <= self.y + self.h
end

function CockpitButton:update(dt)
    -- nothing per-frame for now
end

-- Draw the button.  Call inside love.graphics.setCanvas(scene canvas).
-- debug param: pass true to make buttons visible; false draws them transparent.
function CockpitButton:draw(showDebug)
    if not showDebug then return end

    local x, y, w, h = self.x, self.y, self.w, self.h

    -- Face (white fill)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Outer border
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", x, y, w, h)

    -- Inner shadow on bottom + right (raised 3D look)
    love.graphics.line(x + 1, y + h - 2, x + w - 2, y + h - 2)
    love.graphics.line(x + w - 2, y + 1,   x + w - 2, y + h - 2)

    -- Label
    local font = getLabelFont()
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 1)
    local fontH  = font:getHeight()
    local labelW = font:getWidth(self.label)
    local lx     = x + math.floor((w - labelW) / 2)
    local ly     = y + math.floor((h - fontH)  / 2)
    love.graphics.print(self.label, lx, ly)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return CockpitButton
