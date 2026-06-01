function Player:useAbility()
    if not self.isAlive or PlayerData.isGaming ~= true then
        return
    end
    if self:isOnHole() then return end  -- on a hole the player may only walk
    if PlayerData.isInDarkness then
        self:useLampAbility()
    else
        self:usePlungeAbility()
    end
end

function Player:useLampAbility()
    self:lightBurst()
end

function Player:usePlungeAbility()
    self:plunge()
end

function Player:beginDarkCharge()
    if not PlayerData.isInDarkness or not PlayerData.items.hasLamp then return end
    if self:isOnHole() then return end  -- on a hole the player may only walk
    if PlayerData.battery < Config.DarkReveal.minBattery then return end
    if self.isDarkCharging then return end
    self.isDarkCharging = true
    self.darkCrankAccum = 0
    self.uiHud.animation:setState('crankClock')
    self.uiHud:setVisible(true)
end

function Player:addDarkCrankDelta(delta)
    if not self.isDarkCharging then return end
    if delta > 0 then self.darkCrankAccum += delta end
end

function Player:endDarkCharge()
    if not self.isDarkCharging then return end
    self.isDarkCharging = false
    self.uiHud:setRotation(0)
    self.uiHud:setVisible(false)
    if self:isOnHole() then self.darkCrankAccum = 0; return end  -- walked onto a hole: cancel, no skill
    if self.darkCrankAccum >= Config.DarkReveal.crankThreshold and PlayerData.battery >= Config.DarkReveal.minBattery then
        self:activateDarkReveal()
    else
        self:useLampAbility()
    end
    self.darkCrankAccum = 0
end

function Player:activateDarkReveal()
    PlayerData.battery = 0
    PlayerData.rechargeBlocked = true
    PlayerData.showFullLight = true

    -- Grant enemy/crew movement tokens now that the dark reveal actually activated
    self:distributeMovementTokens(Config.Player.movementTokensPerAction)

    playdate.timer.performAfterDelay(Config.DarkReveal.revealDuration, function()
        PlayerData.showFullLight = false

        playdate.timer.performAfterDelay(Config.DarkReveal.rechargeBlockDuration, function()
            PlayerData.rechargeBlocked = false
        end)
    end)
end
