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

-- Frame indices in button-table-32-32.png (8 frames, 1 row)
local BUTTON_FRAMES = {
    leftButton  = 1,
    upButton    = 2,
    rightButton = 3,
    downButton  = 4,
    aButton     = 5,
    bButton     = 6,
}
local EMPTY_FRAME = 7

local LEFT_BOUNDARY = 20
local _image, _quads  -- module-level cache shared across all instances

local function loadAssets()
    if _image then return end
    _image = love.graphics.newImage('assets/images/ui/battle/button-table-32-32.png')
    _quads = {}
    local fw, fh = 32, 32
    local iw = _image:getWidth()
    local nFrames = math.floor(iw / fw)
    for i = 1, nFrames do
        _quads[i] = love.graphics.newQuad((i-1)*fw, 0, fw, fh, iw, fh)
    end
end

function ButtonPress.new(bpm, startX, keyProvider)
    loadAssets()
    local self = setmetatable({}, ButtonPress)
    self.keyProvider = keyProvider
    self.startX      = startX or 400
    self.buttonKey   = keyProvider()
    self.label       = BUTTON_LABELS[self.buttonKey] or "?"
    self.x           = startX or 400
    self.y           = 40
    self.width       = 32
    self.height      = 32
    self.isHit       = false
    self.hitTimer    = 0
    self.delayMs     = 0
    self.elapsedMs   = 0
    self.speed       = 400 / (60 / bpm)
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
    self.elapsedMs = self.delayMs
end

function ButtonPress:hit()
    self.isHit    = true
    self.hitTimer = 0.15
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
    scale = scale or 1
    local frameIdx = self.isHit and EMPTY_FRAME or (BUTTON_FRAMES[self.buttonKey] or 1)
    local quad = _quads[frameIdx]
    if not quad then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(_image, quad, self.x * scale, self.y * scale, 0, scale, scale)
end

function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
