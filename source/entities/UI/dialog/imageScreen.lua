-- entities/UI/dialog/imageScreen.lua
local Class = require 'libraries/middleclass'

local ImageScreen = Class('ImageScreen')

function ImageScreen:initialize()
    self.image = nil
    self.x = 200 -- Center X of virtual resolution (400/2)
    self.y = 80  -- Default Y for top images
end

function ImageScreen:setImage(image)
    self.image = image
end

function ImageScreen:draw()
    if self.image then
        -- Draw the image centered horizontally
        local imgWidth = self.image:getWidth()
        local imgHeight = self.image:getHeight()
        love.graphics.draw(self.image, self.x - imgWidth/2, self.y - imgHeight/2)
    end
end

function ImageScreen:clear()
    self.image = nil
end

return ImageScreen
