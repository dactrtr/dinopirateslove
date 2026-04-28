-- entities/UI/battle/EnemyRatDance.lua
local anim8 = require 'libraries/anim8'

EnemyRatDance = {}
EnemyRatDance.__index = EnemyRatDance

local ENEMY_X = 158
local ENEMY_Y = 26
local COLS    = 6

local function buildAnim(g, fromFrame, toFrame, fps)
    local quads = {}
    for n = fromFrame, toFrame do
        local col = ((n-1) % COLS) + 1
        local row = math.floor((n-1) / COLS) + 1
        for _, q in ipairs(g(col, row)) do
            quads[#quads+1] = q
        end
    end
    return anim8.newAnimation(quads, 1 / fps)
end

function EnemyRatDance.new(bpm, enemyType, evolving)
    local self = setmetatable({
        bpm=bpm, enemyType=enemyType or "basic", evolving=evolving or false
    }, EnemyRatDance)
    self.image = love.graphics.newImage('assets/images/ui/battle/enemyDance-table-211-214.png')
    local g    = anim8.newGrid(211, 214, self.image:getWidth(), self.image:getHeight())
    local fps  = 10
    self.anims = {
        idle        = buildAnim(g, 1,  5,  fps),
        upAttack    = buildAnim(g, 6,  9,  fps),
        downAttack  = buildAnim(g, 10, 13, fps),
        leftAttack  = buildAnim(g, 14, 17, fps),
        rightAttack = buildAnim(g, 18, 21, fps),
        bButton     = buildAnim(g, 22, 25, fps),
        aButton     = buildAnim(g, 26, 29, fps),
        evolving    = buildAnim(g, 30, 33, fps),
    }

    -- Attack animations play once then pause at last frame
    local attackNames = {"upAttack","downAttack","leftAttack","rightAttack","bButton","aButton","evolving"}
    for _, name in ipairs(attackNames) do
        self.anims[name]:pauseAtEnd()
    end

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
    end
end

function EnemyRatDance:attackAnimation(buttonKey)
    local name = (buttonKey == "aButton") and "aButton" or "bButton"
    if self.anims[name] then
        self.currentAnim = self.anims[name]
        self.currentAnim:gotoFrame(1)
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
    self.currentAnim:draw(self.image, ENEMY_X * scale, ENEMY_Y * scale, 0, scale, scale)
end
