-- src/entities/ButtonCover.lua
-- Draws a mask over the left side so buttons "disappear" when they enter the hit zone.
ButtonCover = {}
ButtonCover.__index = ButtonCover

function ButtonCover.new()
    return setmetatable({}, ButtonCover)
end

function ButtonCover:draw(scale)
    scale = scale or 2
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 100 * scale, 25 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
end
