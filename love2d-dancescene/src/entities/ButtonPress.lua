-- src/entities/ButtonPress.lua
-- Scrolls right→left across the screen. Owned and updated by DanceScene.

ButtonPress = {}
ButtonPress.__index = ButtonPress

-- BUTTON_LABELS: maps key → display character for drawing
local BUTTON_LABELS = {
    aButton    = "A",
    bButton    = "B",
    leftButton = "◀",
    upButton   = "▲",
    rightButton= "▶",
    downButton = "▼",
}

-- bpm        : beats per minute (controls scroll speed)
-- startX     : initial x position in logical coords (pass 400 for right edge)
-- keyProvider: function() → buttonKey string
-- NOTE: movementDelay(ms) must be called separately after construction to stagger buttons.
function ButtonPress.new(bpm, startX, keyProvider)
    local self  = setmetatable({}, ButtonPress)
    self.buttonKey   = keyProvider()
    self.label       = BUTTON_LABELS[self.buttonKey] or "?"
    self.x           = startX or 400  -- logical starting x position
    self.y           = 110            -- vertical center of battle area
    self.width       = 20
    self.height      = 20
    self.isHit       = false
    self.delayMs     = 0              -- set via movementDelay() after construction
    self.elapsedMs   = 0
    -- Speed: cross 400px in (60/bpm) seconds
    self.speed       = 400 / (60 / bpm)   -- px/sec
    return self
end

function ButtonPress:movementDelay(ms)
    self.delayMs = ms
end

function ButtonPress:update(dt)
    if self.isHit then return end
    local dtMs = dt * 1000
    if self.elapsedMs < self.delayMs then
        self.elapsedMs = self.elapsedMs + dtMs
        return
    end
    self.x = self.x - self.speed * dt
end

function ButtonPress:draw(scale)
    if self.isHit then return end
    scale = scale or 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.x * scale, self.y * scale, self.width * scale, self.height * scale)
    love.graphics.printf(self.label, self.x * scale, self.y * scale + 2 * scale, self.width * scale, "center")
end

function ButtonPress:hit()
    self.isHit = true
end

-- Returns axis-aligned bounding box in logical coords
function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
