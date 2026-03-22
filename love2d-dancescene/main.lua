-- main.lua
require "src/SceneManager"
require "src/scenes/TitleScene"
require "src/scenes/DanceScene"

function love.load()
    love.graphics.setBackgroundColor(0, 0, 0)
    love.graphics.setNewFont(12)
    SceneManager.switch(DanceScene.new())
end

function love.update(dt)
    SceneManager.update(dt)
end

function love.draw()
    SceneManager.draw()
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    SceneManager.keypressed(key)
end

function love.keyreleased(key)
    SceneManager.keyreleased(key)
end
