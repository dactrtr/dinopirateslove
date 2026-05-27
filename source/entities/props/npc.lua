-- entities/props/npc.lua
local conditionEval = require 'utilities.conditionEval'
local anim8 = require 'libraries.anim8'

local NPC = {}
NPC.__index = NPC

local FRAME_W, FRAME_H = 32, 32
local _sharedImage = nil

local function getImage()
    if not _sharedImage then
        local ok, img = pcall(love.graphics.newImage, 'assets/images/props/npc.png')
        _sharedImage = ok and img or nil
    end
    return _sharedImage
end

function NPC.new(world, x, y, npcType, iid, room, sourceFeed)
    local self = setmetatable({}, NPC)
    self.world      = world
    self.npcType    = npcType or "computer"
    self.iid        = iid
    self.room       = room
    self.sourceFeed = sourceFeed or 0
    self.isNPC      = true
    self.script     = nil
    self.type       = nil

    self.spriteX = x - FRAME_W / 2
    self.spriteY = y - FRAME_H / 2
    self.spriteW = FRAME_W
    self.spriteH = FRAME_H

    local img = getImage()
    if img then
        local grid     = anim8.newGrid(FRAME_W, FRAME_H, img:getWidth(), img:getHeight())
        local frameMap = {
            cat      = grid('1-4', 1),
            computer = grid('5-8', 1),
        }
        local frames = frameMap[self.npcType] or frameMap["computer"]
        self.anim = anim8.newAnimation(frames, 0.2)
    end

    world:add(self, self.spriteX, self.spriteY, FRAME_W, FRAME_H)

    self.wall = { isNPCWall = true, ownerNPC = self }
    local wallOffset = 4
    world:add(self.wall,
        self.spriteX + wallOffset,
        self.spriteY + wallOffset,
        FRAME_W - wallOffset * 2,
        FRAME_H - wallOffset * 2)

    return self
end

function NPC:update(dt)
    if self.anim then self.anim:update(dt) end
    self.zIndex = self.spriteY + self.spriteH
end

function NPC:draw()
    local img = getImage()
    if not img then
        love.graphics.setColor(0.5, 0.5, 1)
        love.graphics.rectangle("fill", self.spriteX, self.spriteY, FRAME_W, FRAME_H)
        love.graphics.setColor(1, 1, 1)
        return
    end
    love.graphics.setColor(1, 1, 1)
    if self.anim then
        self.anim:draw(img, self.spriteX, self.spriteY)
    else
        love.graphics.draw(img, self.spriteX, self.spriteY)
    end
end

function NPC:remove()
    if self.world:hasItem(self) then self.world:remove(self) end
    if self.wall and self.world:hasItem(self.wall) then
        self.world:remove(self.wall)
        self.wall = nil
    end
end

function NPC:returnScript()
    local cf = self:_getCF()
    local scriptName, grantsStr = conditionEval.evaluateNPC(cf.conditionalScripts)
    if grantsStr and not self:hasGranted() then
        self:applyGrant(grantsStr)
        self:markGranted()
    end
    return scriptName or ""
end

function NPC:applyGrant(grantsStr)
    local grantKey, grantVal = grantsStr:match("^([^:]+):(.+)$")
    if not grantKey or not grantVal then return end
    grantKey = grantKey:gsub("%s+", "")
    if grantKey == "key" then
        local keyNum = tonumber(grantVal)
        if keyNum then PlayerData.keys[keyNum] = true end
    elseif grantVal == "true" then
        PlayerData.items[grantKey] = true
    end
end

function NPC:hasGranted()
    return self:_getCF().hasGranted == true
end

function NPC:markGranted()
    local data = self:_getLDTKData()
    if not data then return end
    if not data.customFields then data.customFields = {} end
    data.customFields.hasGranted = true
end

function NPC:_getLDTKData()
    local roomData = levelsLDTK and levelsLDTK[self.room]
    if not roomData or not roomData.entities or not roomData.entities.NPC then return nil end
    for _, data in ipairs(roomData.entities.NPC) do
        if data.iid == self.iid then return data end
    end
    return nil
end

function NPC:_getCF()
    local data = self:_getLDTKData()
    if not data then return {} end
    return data.customFields or {}
end

return NPC
