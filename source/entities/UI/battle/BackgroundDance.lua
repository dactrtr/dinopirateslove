-- entities/UI/battle/BackgroundDance.lua
BackgroundDance = {}
BackgroundDance.__index = BackgroundDance

function BackgroundDance.new()
    local self = setmetatable({}, BackgroundDance)
    self.image = love.graphics.newImage('assets/images/ui/battle/background-table-400-240.png')
    return self
end

function BackgroundDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, 0, 0, 0, scale, scale)
end
