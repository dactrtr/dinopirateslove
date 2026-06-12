-- entities/UI/battle/PlayerDance.lua
local anim8 = require 'libraries/anim8'

PlayerDance = {}
PlayerDance.__index = PlayerDance

local PLAYER_X  = 0
local PLAYER_Y  = 26
local FRAME_W   = 246
local FRAME_H   = 214

function PlayerDance.new(bpm)
    local self = setmetatable({ bpm = bpm }, PlayerDance)
    local path = PlayerData.isTiny
        and 'assets/images/ui/battle/playerDanceTiny-table-246-214.png'
        or  'assets/images/ui/battle/playerDance-table-246-214.png'
    self.image = love.graphics.newImage(path)
    local g    = anim8.newGrid(246, 214, self.image:getWidth(), self.image:getHeight())
    -- Playdate: frameDuration = bpm/2 (50 fps frames) → bpm/100 seconds
    local frameDur = bpm / 100
    self.anims = {
        idle   = anim8.newAnimation(g('1-5',  1), frameDur),
        jump   = anim8.newAnimation(g('5-9',  1), frameDur, 'pauseAtEnd'),
        crouch = anim8.newAnimation(g('11-15',1), frameDur, 'pauseAtEnd'),
        left   = anim8.newAnimation(g('16-20',1), frameDur, 'pauseAtEnd'),
        right  = anim8.newAnimation(g('21-24',1), frameDur, 'pauseAtEnd'),
    }
    self.currentAnim = self.anims.idle
    return self
end

function PlayerDance:changeAnimation(buttonKey)
    local map = {
        upButton    = "jump",
        downButton  = "crouch",
        leftButton  = "left",
        rightButton = "right",
    }
    local name = map[buttonKey]
    if name and self.anims[name] then
        self.currentAnim = self.anims[name]
        self.currentAnim:gotoFrame(1)
        self.currentAnim:resume()
    end
end

function PlayerDance:setIdle()
    self.currentAnim = self.anims.idle
    self.currentAnim:gotoFrame(1)
end

function PlayerDance:update(dt)
    self.currentAnim:update(dt)
    -- One-shots return to idle when finished (Playdate addState(..., 'idle'))
    if self.currentAnim ~= self.anims.idle and self.currentAnim.status == "paused" then
        self:setIdle()
    end
end

function PlayerDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    self.currentAnim:draw(self.image,
        (PLAYER_X + FRAME_W/2) * scale, (PLAYER_Y + FRAME_H/2) * scale,
        0, scale, scale,
        FRAME_W/2, FRAME_H/2)
end
