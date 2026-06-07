-- entities/props/Door.lua
-- Procedural door (bump entity) for the run-graph rooms.
-- Doors are invisible in the baked room art (the opening is part of the PNG),
-- so they only draw a debug rect. Crossing a door transitions to its target node.

local Class = require 'libraries/middleclass'
local Door = Class('Door')

-- dir: "top"|"down"|"left"|"right"; targetNodeId: graph node to enter on touch.
-- x,y are the authored LDtk door CENTER; width/height the door size.
function Door:initialize(dir, targetNodeId, x, y, width, height, world)
    self.isDoor       = true
    self.direction    = dir
    self.targetNodeId = targetNodeId
    self.world        = world

    local isH = (dir == 'top' or dir == 'down')
    self.width  = width  or (isH and Config.Doors.span or Config.Doors.thickness)
    self.height = height or (isH and Config.Doors.thickness or Config.Doors.span)
    -- LDtk gives center; bump wants top-left.
    self.x = x - self.width  / 2
    self.y = y - self.height / 2
    self.posCross = isH and x or y   -- cross-axis center, for spawn-at-matching-door
    self.zIndex = ZIndex.props
    world:add(self, self.x, self.y, self.width, self.height)
end

function Door:update(dt)
    -- Doors are static; nothing to update.
end

function Door:draw(debug)
    if debug then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Door:remove()
    if self.world and self.world:hasItem(self) then self.world:remove(self) end
end

-- Create door entities from a run-graph node's edges. Each edge (dir -> destNodeId)
-- becomes a door (or several, for a multi-door side) leading to that node.
-- Secret nodes have no `edges`, so the loop is a no-op for them.
function Door.createFromNode(node, world, out)
    if not node or not node.poolRoom then return end
    local template = node.poolRoom
    for dir, destNodeId in pairs(node.edges or {}) do
        local list = MapGenerator.doorsForSide(template, dir)
        if #list > 0 then
            for _, de in ipairs(list) do
                out[#out + 1] = Door:new(dir, destNodeId, de.x, de.y, de.width, de.height, world)
            end
        else
            local pos = Config.Doors.positions[dir]
            if pos then out[#out + 1] = Door:new(dir, destNodeId, pos.x, pos.y, nil, nil, world) end
        end
    end
end

return Door
