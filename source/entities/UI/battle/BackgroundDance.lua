-- entities/UI/battle/BackgroundDance.lua
BackgroundDance = {}
BackgroundDance.__index = BackgroundDance

-- spritePath: resolved by DanceScene (Fight variant); defaults to the base sheet.
function BackgroundDance.new(spritePath)
    local self = setmetatable({}, BackgroundDance)
    self.image = love.graphics.newImage(spritePath or 'assets/images/ui/battle/background-table-400-240.png')
    return self
end

function BackgroundDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, 0, 0, 0, scale, scale)
end
