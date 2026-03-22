-- src/SceneManager.lua
-- Minimal scene manager: push/pop with instant transitions.
-- Scenes must implement: enter(), exit(), update(dt), draw(), keypressed(key), keyreleased(key)
SceneManager = {}
SceneManager.__index = SceneManager

local current = nil

function SceneManager.switch(scene)
    if current and current.exit then current:exit() end
    current = scene
    if current and current.enter then current:enter() end
end

function SceneManager.update(dt)
    if current and current.update then current:update(dt) end
end

function SceneManager.draw()
    if current and current.draw then current:draw() end
end

function SceneManager.keypressed(key)
    if current and current.keypressed then current:keypressed(key) end
end

function SceneManager.keyreleased(key)
    if current and current.keyreleased then current:keyreleased(key) end
end
