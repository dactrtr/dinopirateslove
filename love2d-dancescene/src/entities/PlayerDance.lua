-- src/entities/PlayerDance.lua
-- Displays player state as text for now. Replace with anim8 spritesheet later.
-- States: idle, aButton, bButton, leftButton, rightButton, upButton, downButton
PlayerDance = {}
PlayerDance.__index = PlayerDance

function PlayerDance.new(bpm)
    return setmetatable({ bpm=bpm, state="idle" }, PlayerDance)
end

function PlayerDance:changeAnimation(buttonKey)
    self.state = buttonKey
end

function PlayerDance:setIdle()
    self.state = "idle"
end

function PlayerDance:update(dt) end

function PlayerDance:draw(scale)
    scale = scale or 2
    local x, y = 60 * scale, 150 * scale
    love.graphics.setColor(0.3, 0.6, 1)
    love.graphics.rectangle("fill", x, y, 30 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("P\n" .. self.state:sub(1,3), x, y + 4 * scale, 30 * scale, "center")
end
