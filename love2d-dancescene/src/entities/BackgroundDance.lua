-- src/entities/BackgroundDance.lua
BackgroundDance = {}
BackgroundDance.__index = BackgroundDance

function BackgroundDance.new()
    return setmetatable({}, BackgroundDance)
end

function BackgroundDance:draw(scale)
    scale = scale or 2
    love.graphics.setColor(0.05, 0.05, 0.15)
    love.graphics.rectangle("fill", 0, 0, 400 * scale, 240 * scale)
    love.graphics.setColor(1, 1, 1)
end
