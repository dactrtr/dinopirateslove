-- entities/player/plunge.lua
-- Plungerang ability module for player
local Projectile = require 'entities.player.projectile'

local plunge = {}

-- Attempt to activate the plungerang ability
-- Returns true if successful, false otherwise
function plunge.tryActivate(player)
	-- Validation checks
	
	-- 1. Must have the plunger item
	if not PlayerData.items.hasPlunger then
		printDebug("❌ Plunge failed: Don't have plunger")
		return false
	end
	
	-- 2. Must have the plungerang skill unlocked
	if not PlayerData.skills.canPlungerang then
		printDebug("❌ Plunge failed: Skill not unlocked")
		return false
	end
	
	-- 3. Cannot use while tiny
	if PlayerData.isTiny then
		printDebug("❌ Plunge failed: Cannot use while tiny")
		return false
	end

	-- 4. Only one projectile at a time
	if player.isPlunging or player.projectile then
		printDebug("❌ Plunge failed: Projectile already active")
		return false
	end

	-- 5. Determine fire direction — use last non-idle direction as fallback
	local direction = PlayerData.direction
	if direction == "idle" or not direction then
		direction = PlayerData.lastDirection or "right"
	end
	
	-- All checks passed - activate!
	plunge.activate(player, direction)
	return true
end

function plunge.activate(player, direction)
	printDebug("🪃 Activating Plungerang! Direction: " .. direction)
	
	-- Create projectile
	player.projectile = Projectile(player, direction, player.world)
	
	-- Set plunging state
	player.isPlunging = true

	-- Play the throw pose (one-shot). Only left/right have art, so a vertical throw
	-- uses the right pose. updateAnimation holds this, then the legless idle
	-- (noLegLeft/Right) while the plungerang is out, until it returns → real idle.
	player.shootDir = (direction == "left") and "left" or "right"
	local shootAnim = (player.shootDir == "left") and player.animations.shootLeft
	                                                or player.animations.shootRight
	if shootAnim then
		shootAnim:gotoFrame(1)
		shootAnim:resume()
		player.currentAnimation = shootAnim
	end
end

-- Update function (called from player update if needed)
function plunge.update(player, dt)
	if player.projectile and not player.projectile.destroyed then
		player.projectile:update(dt)
	else
		-- Projectile was destroyed but state wasn't cleared
		if player.isPlunging then
			player.isPlunging = false
			player.projectile = nil
		end
	end
end

return plunge
