-- entities/UI/battle/LoseIndicator.lua
LoseIndicator = {}
LoseIndicator.__index = LoseIndicator

function LoseIndicator.new(x, y)
    return setmetatable({ x=x, y=y }, LoseIndicator)
end

function LoseIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.print("LOSE", self.x * scale, self.y * scale)
    love.graphics.setColor(1, 1, 1)
end
