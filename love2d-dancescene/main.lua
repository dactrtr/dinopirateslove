-- main.lua
require "src/SceneManager"

function love.load()
    -- placeholder: will wire up DanceScene here in Task 11
    love.graphics.setBackgroundColor(0, 0, 0)
end

function love.update(dt)
end

function love.draw()
    love.graphics.print("Scaffold OK", 10, 10)
end
