-- entities/UI/battle/ButtonPress.lua
-- Scrolling input prompt for the dance battle. Mirrors the Playdate original:
-- moves a fixed amount per 50 Hz tick, freezes against other buttons, recycles
-- instantly to the spawn point when hit or past the left edge.
ButtonPress = {}
ButtonPress.__index = ButtonPress

-- Frame indices in button-table-32-32.png — same order as the Playdate sheet.
local BUTTON_FRAMES = {
    aButton     = 1,
    bButton     = 2,
    leftButton  = 3,
    upButton    = 4,
    rightButton = 5,
    downButton  = 6,
}
local EMPTY_FRAME = 8

local SIZE       = 32
local ROW_TOP_Y  = 14   -- Playdate adds at center y=30 → top-left 14
local RECYCLE_X  = 16   -- Playdate recycles at center x<=32 → top-left 16

local _image, _quads  -- module-level cache shared across all instances

local function loadAssets()
    if _image then return end
    _image = love.graphics.newImage('assets/images/ui/battle/button-table-32-32.png')
    _quads = {}
    local iw = _image:getWidth()
    local nFrames = math.floor(iw / SIZE)
    for i = 1, nFrames do
        _quads[i] = love.graphics.newQuad((i-1)*SIZE, 0, SIZE, SIZE, iw, SIZE)
    end
end

-- startCenterX: Playdate passes startPoint+bpm as the sprite CENTER x.
function ButtonPress.new(bpm, startCenterX, keyProvider)
    loadAssets()
    local self = setmetatable({}, ButtonPress)
    self.keyProvider  = keyProvider
    self.startX       = startCenterX - SIZE/2  -- stored as top-left
    self.x            = self.startX
    self.y            = ROW_TOP_Y
    self.width        = SIZE
    self.height       = SIZE
    self.buttonKey    = keyProvider()
    self.active       = false
    self.delayMs      = 0
    self.elapsedMs    = 0
    self.speedPerTick = 0.5 * bpm / 3  -- px per 50 Hz tick (Playdate px/frame)
    return self
end

function ButtonPress:movementDelay(ms)
    self.delayMs = ms
end

-- Real-time stagger timer; runs from scene enter, ready screen included
-- (Playdate uses playdate.timer.performAfterDelay from scene:start()).
function ButtonPress:updateDelay(dtMs)
    if self.active then return end
    self.elapsedMs = self.elapsedMs + dtMs
    if self.elapsedMs >= self.delayMs then
        self.active = true
    end
end

-- Teleport without collision resolution (Playdate moveTo).
function ButtonPress:teleportToStart()
    self.x = self.startX
end

-- Edge recycle: repeat-until-different (Playdate changeButtonSprite).
function ButtonPress:changeButtonSprite()
    local newKey
    repeat
        newKey = self.keyProvider()
    until newKey ~= self.buttonKey
    self.buttonKey = newKey
end

-- Hit recycle: instant; key set to "empty" first, so the re-roll may legally
-- repeat the key that was just hit (faithful to the Playdate original).
function ButtonPress:hit()
    self.buttonKey = "empty"
    self:teleportToStart()
    self:changeButtonSprite()
end

-- One 50 Hz tick of movement. Called only while PlayerData.isDancing.
-- Playdate 'freeze': a moving button stops when it would newly contact another
-- button. Already-overlapping pairs (stacked at spawn) keep moving so they can
-- separate — blocking them would wedge every button at the spawn point.
function ButtonPress:tick(buttons)
    if not self.active then return end
    local goalX = self.x - self.speedPerTick
    for _, other in ipairs(buttons) do
        if other ~= self
            and math.abs(goalX - other.x) < SIZE
            and math.abs(self.x - other.x) >= SIZE then
            goalX = self.x  -- freeze this tick
            break
        end
    end
    self.x = goalX
    if self.x <= RECYCLE_X then
        self:teleportToStart()
        self:changeButtonSprite()
    end
end

function ButtonPress:draw(scale)
    scale = scale or 1
    local frameIdx = BUTTON_FRAMES[self.buttonKey] or EMPTY_FRAME
    local quad = _quads[frameIdx]
    if not quad then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(_image, quad,
        (self.x + SIZE/2) * scale, (self.y + SIZE/2) * scale,
        0, scale, scale,
        SIZE/2, SIZE/2)
end

function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
