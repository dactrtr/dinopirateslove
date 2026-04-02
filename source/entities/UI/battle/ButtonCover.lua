-- entities/UI/battle/ButtonCover.lua
ButtonCover = {}
ButtonCover.__index = ButtonCover

function ButtonCover.new()
    return setmetatable({}, ButtonCover)
end

function ButtonCover:draw(scale)
    scale = scale or 1
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 100 * scale, 25 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
end
