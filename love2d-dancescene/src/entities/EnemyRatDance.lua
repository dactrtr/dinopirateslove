-- src/entities/EnemyRatDance.lua
-- States: idle, attack (per button), plus evolving visual.
EnemyRatDance = {}
EnemyRatDance.__index = EnemyRatDance

function EnemyRatDance.new(bpm, enemyType, evolving)
    return setmetatable({
        bpm       = bpm,
        enemyType = enemyType or "basic",
        evolving  = evolving or false,
        state     = "idle",
    }, EnemyRatDance)
end

function EnemyRatDance:changeAnimation(buttonKey)
    self.state = buttonKey
end

function EnemyRatDance:attackAnimation(buttonKey)
    self.state = "attack_" .. buttonKey
end

function EnemyRatDance:setIdle()
    self.state = "idle"
end

function EnemyRatDance:update(dt) end

function EnemyRatDance:draw(scale)
    scale = scale or 2
    local x, y = 280 * scale, 150 * scale
    local color = self.evolving and {1, 0.5, 0} or {0.8, 0.2, 0.2}
    love.graphics.setColor(table.unpack(color))
    love.graphics.rectangle("fill", x, y, 30 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("E\n" .. self.state:sub(1,3), x, y + 4 * scale, 30 * scale, "center")
end
