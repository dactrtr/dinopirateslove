-- entities/props/PortalDoor.lua
-- Procedural portal (bump entity) linking a host room to a paired secret room.
-- Like Door, portals are invisible in the baked room art, so they only draw a
-- debug rect. Crossing a portal — when its Conditions pass (e.g. the player is
-- tiny) — transitions to the secret-room node the generator paired by PortalID.
-- Ported from DOCS entities/props/portal_door.lua (Playdate/Noble) to LÖVE/bump.

local Class = require 'libraries/middleclass'
local PortalDoor = Class('PortalDoor')

-- The authored Conditions field stores entries like "isTiny:true". The LÖVE
-- Conditions evaluator (utilities/Conditions.lua) treats the part before ':' as a
-- PlayerData path (boolean) and ignores the ':value' label — the Playdate version
-- did the same via condStr:match("^(.-):.+$"). So "isTiny:true" must be normalized
-- to "isTiny" (a boolean path → PlayerData.isTiny == true) before Conditions.met,
-- otherwise it would resolve PlayerData["isTiny:true"] (nil) and never pass.
local function normalizeConditions(list)
    if not list then return nil end
    local out = {}
    for _, entry in ipairs(list) do
        if type(entry) == "string" then
            -- Strip a trailing ":label" for boolean conditions, but keep numeric
            -- comparisons intact (they never contain a ':').
            local stripped = entry:match("^(.-):.+$") or entry
            out[#out + 1] = stripped
        else
            out[#out + 1] = entry
        end
    end
    return out
end

-- pd: the authored LDtk PortalDoors entity (has x,y,width,height,customFields).
-- targetNodeId: the paired secret-room graph node (node.portals[PortalID]).
function PortalDoor:initialize(pd, targetNodeId, world)
    self.isPortal      = true
    self.targetNodeId  = targetNodeId
    self.world         = world

    local cf = pd.customFields or {}
    self.portalId      = cf.PortalID
    self.conditions    = normalizeConditions(cf.Conditions)
    self.spawnX        = cf.SpawnX
    self.spawnY        = cf.SpawnY
    self.blockedDialog = cf.BlockedDialog

    local cr = Config.Portals.collideRect
    self.width  = pd.width  or cr.w
    self.height = pd.height or cr.h
    -- LDtk gives the entity origin already as top-left for these (matching Door,
    -- which converts a center). PortalDoors authored width/height are the collide
    -- size; place the bump rect centered on the authored point like Door does.
    self.x = pd.x - self.width  / 2
    self.y = pd.y - self.height / 2
    self.zIndex = ZIndex.props
    world:add(self, self.x, self.y, self.width, self.height)
end

function PortalDoor:update(dt)
    -- Portals are static; nothing to update.
end

function PortalDoor:draw(debug)
    if debug then
        love.graphics.setColor(0.4, 0.2, 1, 0.4)
        love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function PortalDoor:remove()
    if self.world and self.world:hasItem(self) then self.world:remove(self) end
end

-- Instantiate the PortalDoors authored in a node's room template, wiring each one to
-- the secret-room node the generator paired with it (node.portals[PortalID]). Portals
-- whose secret room isn't in this run (no pairing) are skipped — they stay inert.
-- Secret nodes (and any node without portals) are a no-op.
function PortalDoor.createFromNode(node, world, out)
    if not node or not node.poolRoom then return end
    local portalEntities = node.poolRoom.entities and node.poolRoom.entities.PortalDoors
    if not portalEntities then return end
    local portals = node.portals or {}

    for _, pd in ipairs(portalEntities) do
        local cf = pd.customFields or {}
        local pid = cf.PortalID
        local targetNodeId = pid and portals[pid] or nil
        if targetNodeId then
            out[#out + 1] = PortalDoor:new(pd, targetNodeId, world)
        end
    end
end

return PortalDoor
