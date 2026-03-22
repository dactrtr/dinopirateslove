-- src/entities/ResultsScreen.lua
-- Three states: "loading" (press A to start), "playing" (empty), "win", "lose"
ResultsScreen = {}
ResultsScreen.__index = ResultsScreen

function ResultsScreen.new()
    return setmetatable({ state = "loading" }, ResultsScreen)
end

function ResultsScreen:empty()
    self.state = "playing"
end

function ResultsScreen:win()
    if self.state ~= "win" then self.state = "win" end
end

function ResultsScreen:lose()
    if self.state ~= "lose" then self.state = "lose" end
end

-- Called in update() when isDancing==false and condition==nil (i.e. pre-battle)
function ResultsScreen:loadingScreen()
    self.state = "loading"
end

function ResultsScreen:draw(scale)
    scale = scale or 2
    if self.state == "playing" then return end

    local W = 400 * scale
    local H = 240 * scale

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(1, 1, 1)

    if self.state == "loading" then
        love.graphics.printf("Press A to START BATTLE", 0, H * 0.42, W, "center")
    elseif self.state == "win" then
        love.graphics.setColor(0.2, 1, 0.2)
        love.graphics.printf("YOU WIN!\nPress A to continue", 0, H * 0.375, W, "center")
        love.graphics.setColor(1, 1, 1)
    elseif self.state == "lose" then
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("YOU LOSE!\nPress A to continue", 0, H * 0.375, W, "center")
        love.graphics.setColor(1, 1, 1)
    end
end
