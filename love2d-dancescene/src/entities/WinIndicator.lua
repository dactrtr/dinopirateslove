-- src/entities/WinIndicator.lua
WinIndicator = {}
WinIndicator.__index = WinIndicator

function WinIndicator.new(x, y)
    return setmetatable({ x=x, y=y }, WinIndicator)
end

function WinIndicator:draw(scale)
    scale = scale or 2
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.print("WIN", self.x * scale, self.y * scale)
    love.graphics.setColor(1, 1, 1)
end
