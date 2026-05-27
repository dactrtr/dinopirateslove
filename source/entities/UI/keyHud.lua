-- source/entities/UI/keyHud.lua
-- Key HUD - shows collected keys
-- Supports both PlayerData.hasKey (bool) and PlayerData.keys (array)
local KeyHud = {}

function KeyHud.new(x, y)
    local self = { x = x or 0, y = y or 0, visible = true }
    setmetatable(self, { __index = KeyHud })
    return self
end

function KeyHud:setVisible(v) self.visible = v end

function KeyHud:update(dt) end

function KeyHud:draw()
    if not self.visible then return end
    if not PlayerData then return end

    -- Support array of keys (PlayerData.keys) or single key flag (PlayerData.hasKey)
    if PlayerData.keys and type(PlayerData.keys) == "table" then
        local offsetX = 0
        for i, hasKey in ipairs(PlayerData.keys) do
            if hasKey then
                -- Draw a simple key icon
                love.graphics.setColor(1, 0.8, 0.2)  -- gold
                love.graphics.rectangle("fill", self.x + offsetX, self.y, 6, 10)
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("line", self.x + offsetX, self.y, 6, 10)
                offsetX = offsetX + 8
            end
        end
    elseif PlayerData.hasKey then
        -- Single key
        love.graphics.setColor(1, 0.8, 0.2)  -- gold
        love.graphics.rectangle("fill", self.x, self.y, 6, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", self.x, self.y, 6, 10)
    end

    love.graphics.setColor(1, 1, 1)
end

return KeyHud
