-- entities/UI/battle/PlayerDance.lua
PlayerDance = {}
PlayerDance.__index = PlayerDance

function PlayerDance.new(bpm)
    return setmetatable({ bpm=bpm, state="idle" }, PlayerDance)
end

function PlayerDance:changeAnimation(buttonKey)
    -- Only responds to arrow buttons (directional), not A/B
    if buttonKey == "leftButton" or buttonKey == "rightButton"
    or buttonKey == "upButton"   or buttonKey == "downButton" then
        self.state = buttonKey
    end
end

function PlayerDance:setIdle()
    self.state = "idle"
end

function PlayerDance:update(dt) end

function PlayerDance:draw(scale)
    scale = scale or 1
    local x, y = 60 * scale, 150 * scale
    love.graphics.setColor(0.3, 0.6, 1)
    love.graphics.rectangle("fill", x, y, 30 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("P\n" .. self.state:sub(1,3), x, y + 4 * scale, 30 * scale, "center")
end
