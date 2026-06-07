-- entities/props/WallPlug.lua
-- Covers an unconnected door opening with wall brick (stamped from the tilesheet)
-- and a solid wall collider, so closed doors look solid and can't be walked through.

local Class = require 'libraries/middleclass'
local WallPlug = Class('WallPlug')

local sheet, sheetQuads = nil, {}
local function brickQuad(tileIndex)
    if not sheet then
        sheet = love.graphics.newImage(Config.Doors.plug.tilesheet .. '.png')
        sheet:setFilter('nearest', 'nearest')
    end
    local idx = tileIndex or 1
    if not sheetQuads[idx] then
        local ts = Config.Tiles.size
        local cols = math.floor(sheet:getWidth() / ts)
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        sheetQuads[idx] = love.graphics.newQuad(col * ts, row * ts, ts, ts, sheet:getDimensions())
    end
    return sheet, sheetQuads[idx]
end

function WallPlug:initialize(x, y, w, h, tileIndex, world)
    self.x, self.y, self.width, self.height = x, y, w, h
    self.zIndex = ZIndex.props
    self.world = world
    -- The player wall filter (entities/player/collisions.lua getType) has no special
    -- case for WallPlug, so it falls through to the default 'slide' response — same as
    -- the tile wall colliders. isWall mirrors the tag those colliders carry.
    self.isWall = true
    -- Bake the tiled brick into a canvas once.
    local ts = Config.Tiles.size
    local prevCanvas = love.graphics.getCanvas()
    self.canvas = love.graphics.newCanvas(w, h)
    local img, quad = brickQuad(tileIndex)
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    for ty = 0, h - 1, ts do
        for tx = 0, w - 1, ts do love.graphics.draw(img, quad, tx, ty) end
    end
    love.graphics.setCanvas(prevCanvas)
    world:add(self, x, y, w, h)   -- wall collider
end

function WallPlug:update(dt)
    -- Static; nothing to update.
end

function WallPlug:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.x, self.y)
end

function WallPlug:remove()
    if self.world and self.world:hasItem(self) then self.world:remove(self) end
end

-- For each authored door on a side the graph left UNCONNECTED, stamp a wall plug over
-- its opening. Span axis = door size + trim; perpendicular axis = wall depth from the
-- screen edge (400x240). Authored door x/y is the entity centre.
-- Secret nodes have no `edges`, so every authored door becomes a plug (correct: they
-- have no graph connections; portals are added separately in Phase 3).
function WallPlug.createFromNode(node, world, out)
    if not node or not node.poolRoom then return end
    local doors = node.poolRoom.entities and node.poolRoom.entities.Doors
    if not doors then return end
    local edges = node.edges or {}
    local tile  = Config.Tiles.size
    local cfg   = Config.Doors.plug
    local trim  = (cfg.trimTiles  or 1) * tile
    local depth = (cfg.depthTiles or 1) * tile
    for _, de in ipairs(doors) do
        local conn = de.customFields and de.customFields.DoorsConnection
        local dir  = conn and conn:lower()
        if dir and not edges[dir] then
            local hw, hh = (de.width or 0) / 2, (de.height or 0) / 2
            local x, y, w, h
            if dir == 'top' then
                x, w, y, h = de.x - hw - trim, de.width + 2 * trim, 0, depth
            elseif dir == 'down' then
                x, w, y, h = de.x - hw - trim, de.width + 2 * trim, 240 - depth, depth
            elseif dir == 'left' then
                x, w, y, h = 0, depth, de.y - hh - trim, de.height + trim
            elseif dir == 'right' then
                x, w, y, h = 400 - depth, depth, de.y - hh - trim, de.height + trim
            end
            if x then out[#out + 1] = WallPlug:new(x, y, w, h, cfg.tiles and cfg.tiles[dir], world) end
        end
    end
end

return WallPlug
