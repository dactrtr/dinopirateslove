-- libraries/graphics_compat.lua
-- Compatibility layer for Playdate-style calls used in scripts

Graphics = {}
Graphics.image = {}

function Graphics.image.new(path)
    -- Ensure path works with Love2D (relative to source/ directory)
    local success, img = pcall(love.graphics.newImage, path)
    if success then
        return img
    else
        print("⚠️ Warning: Could not load image at " .. tostring(path))
        return nil
    end
end

local strings = {}

function Graphics.loadStrings(filename)
    if not love.filesystem.getInfo(filename) then
        print("⚠️ Warning: Strings file not found: " .. filename)
        return
    end
    
    for line in love.filesystem.lines(filename) do
        -- Match "key" = "value"
        local key, value = line:match('^"([^"]+)"%s*=%s*"([^"]+)"')
        if key and value then
            strings[key] = value
        end
    end
end

function Graphics.getLocalizedText(key)
    return strings[key] or key
end

return Graphics
