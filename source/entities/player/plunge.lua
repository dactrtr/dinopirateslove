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
	
	-- Lock player to idle animation
	-- The animations module will handle this based on isPlunging flag
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
