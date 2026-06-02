-- entities/player/grapple.lua
-- Grappling hook: the charged variant of the plungerang.
-- The hook ignores ALL sprites (no bump) and only reacts to tiles: a grapplePoint
-- (Config.Tiles.IntGrid.grapplePoint) pulls the player to that tile; a wall (non-walkable
-- tile) or reaching maxDistance makes it return like a boomerang.

local Class        = require 'libraries/middleclass'
local anim8        = require 'libraries/anim8'
local utilities    = require 'utilities'
local playerPlunge = require 'entities.player.plunge'

local grapple = {}

-- ── Tile sampling helper ────────────────────────────────────────────────────
-- Returns (tileId, centerX, centerY) for the tile under world point (px, py).
function grapple.tileUnderPoint(px, py)
    local sceneManager = require 'sceneManager'
    local gameScene = sceneManager.getScene("game")
    if not gameScene or not gameScene.tileMapData then return nil end

    local ts     = gameScene.tileSize
    local startX = VIRTUAL_WIDTH  / 2 - (gameScene.mapWidth  * ts) / 2
    local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * ts) / 2

    local tileId = utilities.getTileUnderPlayer(gameScene.tileMapData, ts, px, py, startX, startY)
    local col    = math.floor((px - startX) / ts)
    local row    = math.floor((py - startY) / ts)
    local cx     = startX + col * ts + ts / 2
    local cy     = startY + row * ts + ts / 2
    return tileId, cx, cy
end

-- ── GrappleHook (projectile; no bump) ───────────────────────────────────────
local GrappleHook = Class('GrappleHook')

function GrappleHook:initialize(player, direction, maxDistance)
    self.player            = player
    self.direction         = direction
    self.maxDistance       = maxDistance
    self.distanceTravelled = 0
    self.returning         = false
    self.finished          = false
    self.speed             = (Config and Config.Grapple and Config.Grapple.projectileSpeed) or 8

    local feet = (Config and Config.Player and Config.Player.feetOffsetY) or 12
    self.x = player.x
    self.y = player.y + feet

    self.spritesheet = love.graphics.newImage('assets/images/items/projectile-table-24-24.png')
    local grid = anim8.newGrid(24, 24, self.spritesheet:getWidth(), self.spritesheet:getHeight())
    self.animation = anim8.newAnimation(grid('1-4', 1), 0.1)
end

function GrappleHook:update(dt)
    self.animation:update(dt)
    local step = self.speed * 60 * dt
    local feet = (Config and Config.Player and Config.Player.feetOffsetY) or 12

    if self.returning then
        local dx = self.player.x - self.x
        local dy = (self.player.y + feet) - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= step then
            self.finished = true
        else
            self.x = self.x + (dx / dist) * step
            self.y = self.y + (dy / dist) * step
        end
        return
    end

    -- Fly out in the launch direction.
    if     self.direction == 'left'  then self.x = self.x - step
    elseif self.direction == 'right' then self.x = self.x + step
    elseif self.direction == 'up'    then self.y = self.y - step
    elseif self.direction == 'down'  then self.y = self.y + step
    end

    local grapplePointId = (Config and Config.Tiles and Config.Tiles.IntGrid and Config.Tiles.IntGrid.grapplePoint) or 33
    local tileId, cx, cy = grapple.tileUnderPoint(self.x, self.y)

    if tileId == grapplePointId then
        -- Land the player's feet on the tile center.
        grapple.startPull(self.player, cx, cy - feet)
        self.finished = true
        return
    elseif not utilities.isTileWalkable(tileId) then
        self.returning = true   -- hit a wall or left the map
        return
    end

    self.distanceTravelled = self.distanceTravelled + step
    if self.distanceTravelled >= self.maxDistance then
        self.returning = true
    end
end

function GrappleHook:draw()
    local feet = (Config and Config.Player and Config.Player.feetOffsetY) or 12

    -- Rope: line from the player's feet to the hook.
    love.graphics.setColor(0.12, 0.11, 0.10, 1)
    love.graphics.setLineWidth((Config and Config.Grapple and Config.Grapple.ropeWidth) or 2)
    love.graphics.line(self.player.x, self.player.y + feet, self.x, self.y)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    -- Hook sprite (centered).
    self.animation:draw(self.spritesheet, self.x, self.y, 0, 1, 1, 12, 12)
end

-- ── Charge / fire (called from input wiring) ────────────────────────────────
function grapple.beginCharge(player)
    if PlayerData.isGaming ~= true then return end
    if player:isOnHole() then return end                  -- on a hole the player may only walk
    if PlayerData.isInDarkness then return end             -- grapple is the lit-room ability
    if not PlayerData.items.hasPlunger or not PlayerData.skills.canPlungerang then return end
    if not player.hasProjectile then return end            -- lost to a CrewMember; recover first
    if PlayerData.isTiny then return end
    if player.isGrappleCharging or player.isPlunging or player.isGrapplePulling or player.isGrappling then return end

    player.isGrappleCharging = true
    player.grappleCrankAccum = 0
    player.grappleChargeStart = love.timer.getTime()
end

function grapple.addCrankDelta(player, delta)
    if not player.isGrappleCharging then return end
    if delta and delta > 0 then
        player.grappleCrankAccum = player.grappleCrankAccum + delta
    end
end

-- Whether the charge has been held long enough to "arm" (else a tap → plunge).
function grapple.isArmed(player)
    if not player.isGrappleCharging then return false end
    local holdDelay = ((Config and Config.Grapple and Config.Grapple.holdDelay) or 400) / 1000
    return (love.timer.getTime() - (player.grappleChargeStart or 0)) >= holdDelay
end

function grapple.endCharge(player)
    -- Not charging (couldn't grapple, e.g. no plunger): treat as a normal plunge tap.
    if not player.isGrappleCharging then
        playerPlunge.tryActivate(player)
        return
    end

    local armed = grapple.isArmed(player)
    player.isGrappleCharging = false

    local dir = PlayerData.direction
    if dir == 'idle' or dir == nil then dir = PlayerData.lastDirection end

    if not armed then
        -- Quick tap → plungerang (existing behavior).
        player.grappleCrankAccum = 0
        playerPlunge.tryActivate(player)
        return
    end

    if not dir or dir == 'idle' then player.grappleCrankAccum = 0; return end
    if player:isOnHole() then player.grappleCrankAccum = 0; return end

    local g = Config.Grapple
    local distance = (g.minDistance or 64) + math.deg(player.grappleCrankAccum) * (g.pixelsPerDegree or 0.4)
    if distance > (g.maxDistance or 320) then distance = g.maxDistance end
    player.grappleCrankAccum = 0

    player.isGrappling = true
    player.grappleHook = GrappleHook(player, dir, distance)
    player:distributeMovementTokens((Config and Config.Player and Config.Player.movementTokensPerAction) or 5)
    player:idle()
end

-- Abort an in-progress charge without firing anything (used when a blocking UI
-- state — dialog, menu, pause, cutscene — interrupts the charge before release).
function grapple.cancelCharge(player)
    player.isGrappleCharging = false
    player.grappleCrankAccum = 0
end

function grapple.onFinished(player)
    player.isGrappling = false
    player.grappleHook = nil
end

-- ── Pull (fast slide to the tile) ───────────────────────────────────────────
function grapple.startPull(player, targetX, targetY)
    player.grappleTargetX = targetX
    player.grappleTargetY = targetY
    player.isGrapplePulling = true
end

function grapple.updatePull(player, dt)
    if not player.isGrapplePulling then return end
    local speed = ((Config and Config.Grapple and Config.Grapple.pullSpeed) or 8) * 60 * dt
    local dx = player.grappleTargetX - player.x
    local dy = player.grappleTargetY - player.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= speed then
        player:moveTo(player.grappleTargetX, player.grappleTargetY)
        player.isGrapplePulling = false
        PlayerData.direction = 'idle'
        player:idle()
    else
        player:moveTo(player.x + (dx / dist) * speed, player.y + (dy / dist) * speed)
    end
end

-- ── Per-frame update / draw (called from Player) ────────────────────────────
function grapple.update(player, dt)
    if player.grappleHook then
        player.grappleHook:update(dt)
        if player.grappleHook.finished then
            grapple.onFinished(player)
        end
    end
end

function grapple.draw(player)
    if player.grappleHook then player.grappleHook:draw() end
end

return grapple
