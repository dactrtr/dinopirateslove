-- entities/UI/battle/ButtonPress.lua
ButtonPress = {}
ButtonPress.__index = ButtonPress

local BUTTON_LABELS = {
    aButton    = "A",
    bButton    = "B",
    leftButton = "◀",
    upButton   = "▲",
    rightButton= "▶",
    downButton = "▼",
}

local LEFT_BOUNDARY = 20  -- recycle when button exits left side

-- bpm        : beats per minute (controls scroll speed)
-- startX     : x position to reset to after recycling
-- keyProvider: function() → buttonKey string
function ButtonPress.new(bpm, startX, keyProvider)
    local self = setmetatable({}, ButtonPress)
    self.keyProvider = keyProvider
    self.startX      = startX or 400
    self.buttonKey   = keyProvider()
    self.label       = BUTTON_LABELS[self.buttonKey] or "?"
    self.x           = startX or 400
    self.y           = 40         -- aligns with HitZone at y=30, h=40
    self.width       = 32
    self.height      = 32
    self.isHit       = false
    self.hitTimer    = 0
    self.delayMs     = 0
    self.elapsedMs   = 0
    self.speed       = 400 / (60 / bpm)  -- px/sec
    return self
end

function ButtonPress:movementDelay(ms)
    self.delayMs = ms
end

function ButtonPress:recycle()
    self.x         = self.startX
    self.buttonKey = self.keyProvider()
    self.label     = BUTTON_LABELS[self.buttonKey] or "?"
    self.isHit     = false
    self.hitTimer  = 0
    self.elapsedMs = self.delayMs  -- skip delay on subsequent passes
end

function ButtonPress:hit()
    self.isHit    = true
    self.hitTimer = 0.15  -- 150 ms empty state, then recycle
end

function ButtonPress:update(dt)
    if self.hitTimer > 0 then
        self.hitTimer = self.hitTimer - dt
        if self.hitTimer <= 0 then
            self:recycle()
        end
        return
    end

    if self.isHit then return end

    local dtMs = dt * 1000
    if self.elapsedMs < self.delayMs then
        self.elapsedMs = self.elapsedMs + dtMs
        return
    end

    self.x = self.x - self.speed * dt

    if self.x < LEFT_BOUNDARY - self.width then
        self:recycle()
    end
end

function ButtonPress:draw(scale)
    if self.isHit then return end
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line",
        self.x * scale, self.y * scale,
        self.width * scale, self.height * scale)
    love.graphics.printf(self.label,
        self.x * scale, self.y * scale + 8 * scale,
        self.width * scale, "center")
end

function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
