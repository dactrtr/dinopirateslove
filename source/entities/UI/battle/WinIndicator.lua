-- entities/UI/battle/WinIndicator.lua
WinIndicator = {}
WinIndicator.__index = WinIndicator

local FRAME_W = 39
local FRAME_H = 31

function WinIndicator.new(x, y)
    local self = setmetatable({ x = x, y = y }, WinIndicator)
    self.image = love.graphics.newImage('assets/images/ui/battle/enemyIndicator-table-39-31.png')
    return self
end

function WinIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image,
        (self.x + FRAME_W/2) * scale, (self.y + FRAME_H/2) * scale,
        0, scale, scale,
        FRAME_W/2, FRAME_H/2)
end
