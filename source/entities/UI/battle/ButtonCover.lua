-- entities/UI/battle/ButtonCover.lua
ButtonCover = {}
ButtonCover.__index = ButtonCover

local COVER_X  = 361
local COVER_Y  = 32
local FRAME_W  = 78
local FRAME_H  = 58

function ButtonCover.new()
    local self = setmetatable({}, ButtonCover)
    self.image = love.graphics.newImage('assets/images/ui/battle/buttoncover-table-78-58.png')
    return self
end

function ButtonCover:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image,
        COVER_X * scale, COVER_Y * scale,
        0, scale, scale,
        FRAME_W/2, FRAME_H/2)
end
