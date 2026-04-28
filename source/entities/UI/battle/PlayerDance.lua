-- entities/UI/battle/PlayerDance.lua
local anim8 = require 'libraries/anim8'

PlayerDance = {}
PlayerDance.__index = PlayerDance

local PLAYER_X = 0
local PLAYER_Y = 26

function PlayerDance.new(bpm)
    local self = setmetatable({ bpm = bpm }, PlayerDance)
    self.image = love.graphics.newImage('assets/images/ui/battle/playerDance-table-246-214.png')
    local g    = anim8.newGrid(246, 214, self.image:getWidth(), self.image:getHeight())
    local fps  = 10
    self.anims = {
        idle   = anim8.newAnimation(g('1-4',  1), 1/fps),
        jump   = anim8.newAnimation(g('5-9',  1), 1/fps),
        crouch = anim8.newAnimation(g('11-15',1), 1/fps),
        left   = anim8.newAnimation(g('16-20',1), 1/fps),
        right  = anim8.newAnimation(g('21-24',1), 1/fps),
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
    end
end

function PlayerDance:setIdle()
    self.currentAnim = self.anims.idle
end

function PlayerDance:update(dt)
    self.currentAnim:update(dt)
end

function PlayerDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    self.currentAnim:draw(self.image, PLAYER_X * scale, PLAYER_Y * scale, 0, scale, scale)
end
