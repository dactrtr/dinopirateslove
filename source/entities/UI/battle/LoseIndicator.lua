-- entities/UI/battle/LoseIndicator.lua
LoseIndicator = {}
LoseIndicator.__index = LoseIndicator

function LoseIndicator.new(x, y)
    local self = setmetatable({ x = x, y = y }, LoseIndicator)
    self.image = love.graphics.newImage('assets/images/ui/battle/playerIndicator-table-39-31.png')
    return self
end

function LoseIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, self.x * scale, self.y * scale, 0, scale, scale)
end
