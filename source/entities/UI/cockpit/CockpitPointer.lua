-- entities/UI/cockpit/CockpitPointer.lua
-- Port of the Playdate CockpitPointer (NobleSprite) to LÖVE 2D.
-- Animated cursor sprite using anim8.  Falls back to a plain circle when the
-- asset is unavailable so the scene always renders something useful.

local anim8 = require 'libraries/anim8'

local CockpitPointer = {}

-- Sprite sheet layout: 4 frames of 28×28, arranged horizontally.
-- Frames 1-2 = idle animation, frames 3-4 = hover animation.
local FRAME_W   = 28
local FRAME_H   = 28
local FRAME_DUR = 8 / 60   -- 8 frames @ 60 fps  →  0.133 s per anim frame

function CockpitPointer.new()
    local self = {
        x         = 200,
        y         = 120,
        state     = "idle",  -- "idle" | "hover"
        -- sprite
        image     = nil,
        grid      = nil,
        animations = {},
        anim      = nil,     -- current anim8 animation
        -- fallback flag (no asset present)
        useFallback = false,
    }

    -- Try loading the sprite sheet
    local ok, img = pcall(love.graphics.newImage, 'assets/images/ui/cockpit/ui-pointer.png')
    if ok then
        self.image = img
        self.grid  = anim8.newGrid(FRAME_W, FRAME_H, img:getWidth(), img:getHeight())
        self.animations.idle  = anim8.newAnimation(self.grid('1-2', 1), FRAME_DUR)
        self.animations.hover = anim8.newAnimation(self.grid('3-4', 1), FRAME_DUR)
        self.anim = self.animations.idle
    else
        self.useFallback = true
    end

    return self
end

function CockpitPointer:moveTo(x, y)
    self.x = x
    self.y = y
end

function CockpitPointer:setHover()
    if self.state ~= "hover" and not self.useFallback then
        self.state = "hover"
        self.anim  = self.animations.hover
        self.anim:gotoFrame(1)
    elseif self.useFallback then
        self.state = "hover"
    end
end

function CockpitPointer:setIdle()
    if self.state ~= "idle" and not self.useFallback then
        self.state = "idle"
        self.anim  = self.animations.idle
        self.anim:gotoFrame(1)
    elseif self.useFallback then
        self.state = "idle"
    end
end

function CockpitPointer:update(dt)
    if self.anim then
        self.anim:update(dt)
    end
end

function CockpitPointer:draw()
    if self.useFallback then
        -- Draw a simple crosshair circle as placeholder
        local r = Config.Cockpit.pointerRadius or 6
        if self.state == "hover" then
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.circle("fill", self.x, self.y, r)
        else
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("line", self.x, self.y, r)
        end
        love.graphics.setColor(1, 1, 1, 1)
    else
        -- Draw centered on (x, y)
        love.graphics.setColor(1, 1, 1, 1)
        self.anim:draw(self.image,
            math.floor(self.x - FRAME_W / 2),
            math.floor(self.y - FRAME_H / 2))
    end
end

-- Kept for API symmetry; no Bump world involvement in this scene
function CockpitPointer:remove() end

return CockpitPointer
