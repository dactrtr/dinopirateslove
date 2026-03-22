-- src/scenes/TitleScene.lua
TitleScene = {}
TitleScene.__index = TitleScene

function TitleScene.new()
    return setmetatable({}, TitleScene)
end

function TitleScene:enter() end
function TitleScene:exit()  end

function TitleScene:update(dt)
    if love.keyboard.isDown("return") then
        -- Restart: switch back to DanceScene
        SceneManager.switch(DanceScene.new())
    end
end

function TitleScene:draw()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, 800, 480)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.printf("GAME OVER\n\nPress Enter to restart", 0, 180, 800, "center")
    love.graphics.setColor(1, 1, 1)
end

function TitleScene:keypressed(key) end
function TitleScene:keyreleased(key) end
