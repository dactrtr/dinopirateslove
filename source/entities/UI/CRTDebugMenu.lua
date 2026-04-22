local CRTDebugMenu = {}

local visible = false

function CRTDebugMenu.draw()
    if not visible then return end
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("CRT DEBUG [N cerrar]", love.graphics.getWidth() - 200, 10)
    love.graphics.setColor(1, 1, 1, 1)
end

function CRTDebugMenu.keypressed(key)
    if key == "n" then visible = not visible; return true end
    if not visible then return false end
    if key == "escape" then visible = false end
    return true
end

function CRTDebugMenu.loadFromDisk() end

return CRTDebugMenu
