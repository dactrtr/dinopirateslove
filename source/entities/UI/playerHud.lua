-- entities/UI/playerHud.lua
-- LÖVE 2D port of the Playdate playerHud + healthIndicator + battery
-- Draws the HUD (sanity background, battery bar, health hearts) above the player.
-- Visibility gated on PlayerData.items.hasDWatch.

local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local PlayerHud = Class('PlayerHud')

-- Health square pixel offsets within the 35×15 HUD sprite (sprite-local coords)
local HEALTH_X = {4, 5, 10, 11, 16, 17, 22, 23, 28, 29}
local HEALTH_Y = 8
local HEALTH_W = 2
local HEALTH_H = 3

-- Max battery bar width in pixels (matches original)
local BATTERY_MAX_W = 27
local BATTERY_BAR_H = 2

-- Sprite is 35×15, drawn centered: top-left is (tx-17, ty-7)
local SPRITE_W = 35
local SPRITE_H = 15
local SPRITE_OX = math.floor(SPRITE_W / 2)  -- 17
local SPRITE_OY = math.floor(SPRITE_H / 2)  -- 7

-- Helper: concatenate anim8 frame lists (needed for frames that span rows)
local function frames(...)
    local result = {}
    for _, frameList in ipairs({...}) do
        for _, f in ipairs(frameList) do
            table.insert(result, f)
        end
    end
    return result
end

function PlayerHud:initialize()
    self.image = love.graphics.newImage('assets/images/ui/UIHud-table-35-15.png')
    local iw = self.image:getWidth()   -- 175
    local ih = self.image:getHeight()  -- 45

    -- Grid: 5 columns × 3 rows of 35×15 frames (15 frames total)
    local grid = anim8.newGrid(SPRITE_W, SPRITE_H, iw, ih)

    -- Frame mapping (linear frame → col/row in a 5-wide grid):
    -- f1=(1,1) f2=(2,1) f3=(3,1) f4=(4,1) f5=(5,1)
    -- f6=(1,2) f7=(2,2) f8=(3,2) f9=(4,2) f10=(5,2)
    -- f11=(1,3) f12=(2,3) f13=(3,3)
    local fd = 12 / 50  -- 12 Playdate frames at 50fps → ~0.24s per frame

    self.animations = {
        sanity100 = anim8.newAnimation(frames(grid(1,1)),                      fd),
        sanity80  = anim8.newAnimation(frames(grid('3-4',1)),                  fd),
        sanity60  = anim8.newAnimation(frames(grid(5,1), grid(1,2)),           fd),
        sanity40  = anim8.newAnimation(frames(grid('2-4',2)),                  fd),
        sanity20  = anim8.newAnimation(frames(grid(5,2), grid(1,3)),           fd),
        sanity0   = anim8.newAnimation(frames(grid('2-3',3)),                  fd),
    }

    self.currentState = 'sanity100'
    self.currentAnim  = self.animations.sanity100
end

local function getSanityState(sanity)
    if     sanity > 80 then return 'sanity100'
    elseif sanity > 60 then return 'sanity80'
    elseif sanity > 40 then return 'sanity60'
    elseif sanity > 20 then return 'sanity40'
    elseif sanity > 0  then return 'sanity20'
    else                     return 'sanity0'
    end
end

function PlayerHud:update(dt)
    if not PlayerData then return end
    local state = getSanityState(PlayerData.sanity or 100)
    if state ~= self.currentState then
        self.currentState = state
        self.currentAnim  = self.animations[state]
    end
    self.currentAnim:update(dt)
end

function PlayerHud:draw(player)
    if not PlayerData then return end
    if not PlayerData.items or not PlayerData.items.hasDWatch then return end

    local yOffset = PlayerData.isTiny and -22 or -36
    local tx = math.floor(player.x)
    local ty = math.floor(player.y + yOffset)

    -- Sprite top-left corner
    local sx = tx - SPRITE_OX
    local sy = ty - SPRITE_OY

    -- 1. HUD background (sanity animation)
    love.graphics.setColor(1, 1, 1)
    self.currentAnim:draw(self.image, sx, sy)

    -- 2. Battery bar at (tx, ty-3) — drawn as a left-aligned black bar
    --    Left edge: 4px padding from sprite left edge → sx+4 = tx-13
    local battery = math.max(0, PlayerData.battery or 0)
    local batteryW = math.floor((battery * BATTERY_MAX_W) / 100)
    if batteryW > 0 then
        love.graphics.setColor(0.196, 0.184, 0.161)
        love.graphics.rectangle('fill', sx + 4, ty - 3 - 1, batteryW, BATTERY_BAR_H)
    end

    -- 3. Health squares (one black square per health point, up to 10)
    local hp = math.max(0, math.min(math.floor(PlayerData.healthPoints or 0), 10))
    if hp > 0 then
        love.graphics.setColor(0.196, 0.184, 0.161)
        for i = 1, hp do
            if HEALTH_X[i] then
                love.graphics.rectangle('fill',
                    sx + HEALTH_X[i],
                    sy + HEALTH_Y,
                    HEALTH_W, HEALTH_H)
            end
        end
    end

    love.graphics.setColor(1, 1, 1)
end

return PlayerHud
