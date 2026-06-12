-- entities/UI/battle/EnemyRatDance.lua
local anim8 = require 'libraries/anim8'

EnemyRatDance = {}
EnemyRatDance.__index = EnemyRatDance

local ENEMY_X = 158
local ENEMY_Y = 26
local COLS    = 6
local FRAME_W = 211
local FRAME_H = 214

local function buildAnim(g, fromFrame, toFrame, frameDur, onLoop)
    local quads = {}
    for n = fromFrame, toFrame do
        local col = ((n-1) % COLS) + 1
        local row = math.floor((n-1) / COLS) + 1
        for _, q in ipairs(g(col, row)) do
            quads[#quads+1] = q
        end
    end
    return anim8.newAnimation(quads, frameDur, onLoop)
end

function EnemyRatDance.new(bpm, enemyType, evolving)
    local self = setmetatable({
        bpm=bpm, enemyType=enemyType or "basic", evolving=evolving or false
    }, EnemyRatDance)
    self.image = love.graphics.newImage('assets/images/ui/battle/enemyDance-table-211-214.png')
    local g    = anim8.newGrid(211, 214, self.image:getWidth(), self.image:getHeight())
    -- Playdate: frameDuration = bpm/2 frames → bpm/100 s; aButton/bButton are
    -- hardcoded to 3 frames → 0.06 s
    local frameDur = bpm / 100
    self.anims = {
        idle        = buildAnim(g, 1,  5,  frameDur),
        upAttack    = buildAnim(g, 6,  9,  frameDur, 'pauseAtEnd'),
        leftAttack  = buildAnim(g, 10, 13, frameDur, 'pauseAtEnd'),
        rightAttack = buildAnim(g, 14, 17, frameDur, 'pauseAtEnd'),
        downAttack  = buildAnim(g, 18, 21, frameDur, 'pauseAtEnd'),
        bButton     = buildAnim(g, 22, 25, 0.06,     'pauseAtEnd'),
        aButton     = buildAnim(g, 26, 29, 0.06,     'pauseAtEnd'),
        evolving    = buildAnim(g, 30, 33, frameDur),
    }

    self.currentAnim = self.anims.idle
    return self
end

-- Called when a button prompt is visible in the hit zone
local ZONE_MAP = {
    downButton  = "upAttack",
    upButton    = "downAttack",
    leftButton  = "leftAttack",
    rightButton = "rightAttack",
}

function EnemyRatDance:changeAnimation(buttonKey)
    local name = ZONE_MAP[buttonKey]
    if name and self.anims[name] then
        self.currentAnim = self.anims[name]
        self.currentAnim:gotoFrame(1)
        self.currentAnim:resume()
    end
end

function EnemyRatDance:attackAnimation(buttonKey)
    local name = (buttonKey == "aButton") and "aButton" or "bButton"
    if self.anims[name] then
        self.currentAnim = self.anims[name]
        self.currentAnim:gotoFrame(1)
        self.currentAnim:resume()
    end
end

function EnemyRatDance:setIdle()
    self.currentAnim = self.anims.idle
    self.currentAnim:gotoFrame(1)
end

function EnemyRatDance:update(dt)
    self.currentAnim:update(dt)
    -- Return to idle when a non-looping attack finishes
    if self.currentAnim ~= self.anims.idle and self.currentAnim.status == "paused" then
        self:setIdle()
    end
end

function EnemyRatDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    self.currentAnim:draw(self.image,
        (ENEMY_X + FRAME_W/2) * scale, (ENEMY_Y + FRAME_H/2) * scale,
        0, scale, scale,
        FRAME_W/2, FRAME_H/2)
end
