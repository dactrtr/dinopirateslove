-- entities/UI/dialog/videoFeed.lua
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local VideoFeed = Class('VideoFeed')

function VideoFeed:initialize()
    -- Explicitly using the file we confirmed exists
    self.imagePath = 'assets/images/ui/dialog/videoFeed-table-118-94.png'
    self.image = love.graphics.newImage(self.imagePath)
    local w, h = 118, 94
    self.grid = anim8.newGrid(w, h, self.image:getWidth(), self.image:getHeight())
    
    -- Linear frame mapping helper (1-based index)
    local function f(n)
        local cols = 4
        local row = math.ceil(n / cols)
        local col = n - (row - 1) * cols
        return col, row
    end

    -- Map each state based on the original Playdate code indices
    -- We must be careful with f(n) expansion if not the last argument
    local c4, r4 = f(4)
    local c5, r5 = f(5)

    self.animations = {
        ['player'] = anim8.newAnimation(self.grid(f(1)), 1),
        ['player-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['radioHand'] = anim8.newAnimation(self.grid(f(2)), 1),
        ['radioHand-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['radioPocket'] = anim8.newAnimation(self.grid(f(3)), 1),
        ['radioPocket-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['radioRing'] = anim8.newAnimation(self.grid(c4, r4, c5, r5), 0.2), 
        ['radioRing-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['notesHand'] = anim8.newAnimation(self.grid(f(6)), 1),
        ['notesHand-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['playerWorry'] = anim8.newAnimation(self.grid(f(7)), 1),
        ['playerWorry-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['playerSurprise'] = anim8.newAnimation(self.grid(f(8)), 1),
        ['playerSurprise-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['playerHappy'] = anim8.newAnimation(self.grid(f(9)), 1),
        ['playerHappy-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['playerAngry'] = anim8.newAnimation(self.grid(f(10)), 1),
        ['playerAngry-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['playerSleepy'] = anim8.newAnimation(self.grid(f(11)), 1),
        ['playerSleepy-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['playerScared'] = anim8.newAnimation(self.grid(f(12)), 1),
        ['playerScared-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['playerCry'] = anim8.newAnimation(self.grid(f(12)), 1),
        ['playerCry-tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
        
        ['tiny'] = anim8.newAnimation(self.grid(f(14)), 1),
    }
    
    self.currentAnimation = self.animations.player
    self.state = "player"
end

function VideoFeed:setState(state)
    local targetState = state
    
    if PlayerData.isTiny then
        local tinyState = state .. "-tiny"
        if self.animations[tinyState] then
            targetState = tinyState
        else
            targetState = "tiny"
        end
    end
    
    if self.animations[targetState] then
        self.state = targetState
        self.currentAnimation = self.animations[targetState]
    else
        printDebug("⚠️ Warning: VideoFeed state not found: " .. tostring(targetState))
        self.currentAnimation = self.animations.player
    end
end

function VideoFeed:update(dt)
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end
end

function VideoFeed:draw(x, y)
    if self.currentAnimation then
        self.currentAnimation:draw(self.image, x, y)
    end
end

return VideoFeed
