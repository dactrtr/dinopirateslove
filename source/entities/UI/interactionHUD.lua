-- entities/UI/interactionHUD.lua
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local InteractionHUD = Class('InteractionHUD')

function InteractionHUD:initialize()
    self.imagePath = 'assets/images/ui/interaction-table-22-37.png'
    self.image = love.graphics.newImage(self.imagePath)
    
    local fw, fh = 22, 37
    self.grid = anim8.newGrid(fw, fh, self.image:getWidth(), self.image:getHeight())
    
    -- Map each state to linear frame index (1-based)
    -- Based on original code mappings:
    -- pressA: 1-6
    -- ring: 7-8
    -- answer: 9-14
    -- crankAntiClock: 15-18
    -- crankClock: 19-22
    -- Investigate: 23-28
    
    self.animations = {
        pressA = anim8.newAnimation(self.grid('1-6', 1), 0.1),
        ring = anim8.newAnimation(self.grid('7-8', 1), 0.1),
        answer = anim8.newAnimation(self.grid('9-14', 1), 0.1),
        crankAntiClock = anim8.newAnimation(self.grid('15-18', 1), 0.1),
        crankClock = anim8.newAnimation(self.grid('19-22', 1), 0.1),
        Investigate = anim8.newAnimation(self.grid('23-28', 1), 0.1)
    }
    
    self.currentAnimation = self.animations.pressA
    self.visible = false
    self.x = 0
    self.y = 0
end

function InteractionHUD:setState(state)
    if self.animations[state] then
        self.currentAnimation = self.animations[state]
    else
        -- Fallback for 'Search' -> 'Investigate', 'Call' -> 'ring'
        if state == "Search" then 
            self.currentAnimation = self.animations.Investigate
        elseif state == "Call" then
            self.currentAnimation = self.animations.ring
        elseif state == "Confirm" or state == "PressA" or not state then
            self.currentAnimation = self.animations.pressA
        end
    end
end

function InteractionHUD:update(dt)
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end
end

function InteractionHUD:draw(x, y)
    if not self.visible then return end
    
    if self.currentAnimation then
        -- Draw centered horizontally above the given x, y
        self.currentAnimation:draw(self.image, x + 24, y - 40)
    end
end

function InteractionHUD:setVisible(visible)
    self.visible = visible
end

return InteractionHUD
