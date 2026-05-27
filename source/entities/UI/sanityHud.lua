-- source/entities/UI/sanityHud.lua
-- Sanity HUD - shows the player's sanity level
local SanityHud = {}

function SanityHud.new(x, y)
    local self = {
        x = x or 0,
        y = y or 0,
        visible = true,
    }
    setmetatable(self, { __index = SanityHud })
    return self
end

function SanityHud:setVisible(v)
    self.visible = v
end

function SanityHud:update(dt)
    -- nothing to update per-frame
end

function SanityHud:draw()
    if not self.visible then return end
    if not PlayerData then return end

    local sanity = PlayerData.sanity or 100
    local maxSanity = PlayerData.maxSanity or 100
    local pct = math.max(0, sanity) / math.max(1, maxSanity)

    -- Draw sanity bar (purple tones)
    local barW = 36
    local barH = 4
    -- Background
    love.graphics.setColor(0.2, 0.1, 0.2)
    love.graphics.rectangle("fill", self.x, self.y, barW, barH)
    -- Fill
    local fillColor = pct > 0.5 and {0.6, 0.2, 0.8} or {0.9, 0.1, 0.1}
    love.graphics.setColor(unpack(fillColor))
    love.graphics.rectangle("fill", self.x, self.y, barW * pct, barH)
    -- Outline
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("line", self.x, self.y, barW, barH)

    love.graphics.setColor(1, 1, 1)
end

return SanityHud
