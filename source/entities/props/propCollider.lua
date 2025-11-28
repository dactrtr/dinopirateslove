local Class = require 'libraries/middleclass'

local PropCollider = Class('PropCollider')

function PropCollider:initialize(x, y, width, height, world)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.world = world
    self.class = PropCollider -- For type checking
    self.isPropCollider = true
    
    -- Add to BUMP world
    if self.world then
        self.world:add(self, self.x, self.y, self.width, self.height)
    end
end

function PropCollider:remove()
    if self.world and self.world:hasItem(self) then
        self.world:remove(self)
    end
end

return PropCollider