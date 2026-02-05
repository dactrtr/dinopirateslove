-- entities/player/animations.lua
-- Animation-related functions for Player

local anim8 = require 'libraries/anim8'

local animations = {}

-- Helper to convert linear range to anim8 frames
local function getFrames(grid, startIdx, endIdx, cols)
	local frames = {}
	for i = startIdx, endIdx do
		local row = math.ceil(i / cols)
		local col = (i - 1) % cols + 1
		table.insert(frames, grid(col, row)[1])
	end
	return frames
end

-- Load all player animations
function animations.load(spritesheet)
	local frameW, frameH = 48, 48
	local imageW, imageH = spritesheet:getDimensions()
	local cols = math.floor(imageW / frameW)
	
	local grid = anim8.newGrid(frameW, frameH, imageW, imageH)
	
	-- Durations (approximate based on Playdate ticks @ 30fps)
	local durIdle = 0.4    -- 12 ticks
	local durWalk = 0.26   -- 8 ticks
	local durTiny = 0.13   -- 4 ticks
	local durDash = 0.1    -- 3 ticks
	
	return {
		-- Normal Movement
		left = anim8.newAnimation(getFrames(grid, 1, 5, cols), durWalk),
		right = anim8.newAnimation(getFrames(grid, 11, 15, cols), durWalk),
		up = anim8.newAnimation(getFrames(grid, 21, 25, cols), durWalk),
		down = anim8.newAnimation(getFrames(grid, 26, 30, cols), durWalk),
		idle = anim8.newAnimation(getFrames(grid, 41, 52, cols), durIdle),
		
		-- Lamp Movement
		lampLeft = anim8.newAnimation(getFrames(grid, 6, 10, cols), durWalk),
		lampRight = anim8.newAnimation(getFrames(grid, 16, 20, cols), durWalk),
		lampDown = anim8.newAnimation(getFrames(grid, 31, 35, cols), durWalk),
		lampIdle = anim8.newAnimation(getFrames(grid, 53, 64, cols), durIdle),
		
		-- Actions
		charge = anim8.newAnimation(getFrames(grid, 36, 40, cols), 0.4), -- 12 ticks
		
		-- Dashing
		dashRight = anim8.newAnimation(getFrames(grid, 65, 68, cols), durDash),
		dashLeft  = anim8.newAnimation(getFrames(grid, 69, 72, cols), durDash), -- Note: User repeated 65-68 for others, assume typos or sharing frames?
		-- User code: dashRight 65-68, dashLeft 69-72. dashUp/Down 65-68. 
		-- I will follow user code strictly where unique, and reuse for up/down fallback.
		dashUp    = anim8.newAnimation(getFrames(grid, 65, 68, cols), durDash),
		dashDown  = anim8.newAnimation(getFrames(grid, 65, 68, cols), durDash),

		-- Tiny Mode
		tinyIdle  = anim8.newAnimation(getFrames(grid, 73, 81, cols), durTiny),
		tinyRight = anim8.newAnimation(getFrames(grid, 82, 84, cols), durTiny),
		tinyLeft  = anim8.newAnimation(getFrames(grid, 85, 87, cols), durTiny),
		tinyDown  = anim8.newAnimation(getFrames(grid, 88, 90, cols), durTiny),
		tinyUp    = anim8.newAnimation(getFrames(grid, 91, 93, cols), durTiny),
		
		-- Transitions
		transformTo    = anim8.newAnimation(getFrames(grid, 94, 99, cols), 0.13), -- 4 ticks
		transformCycle = anim8.newAnimation(getFrames(grid, 100, 105, cols), 0.1) -- 3 ticks
	}
end

-- Get initial animation based on player state
function animations.getInitialAnimation(animList)
	if PlayerData.isTiny then
		return animList.tinyIdle
	elseif PlayerData.hasLamp and PlayerData.isInDarkness then
		return animList.lampIdle
	else
		return animList.idle
	end
end

-- Update animation based on movement direction
function animations.updateAnimation(player, dx, dy)
	local anims = player.animations
	
	if PlayerData.isTiny then
		if dx > 0 then
			player.currentAnimation = anims.tinyRight
		elseif dx < 0 then
			player.currentAnimation = anims.tinyLeft
		elseif dy > 0 then
			player.currentAnimation = anims.tinyDown
		elseif dy < 0 then
			player.currentAnimation = anims.tinyUp
		else
			player.currentAnimation = anims.tinyIdle
		end
	else
		-- Normal / Lamp logic
		-- Check dash state if implemented later, for now just walk
		
		if dx > 0 then
			player.currentAnimation = PlayerData.hasLamp and anims.lampRight or anims.right
		elseif dx < 0 then
			player.currentAnimation = PlayerData.hasLamp and anims.lampLeft or anims.left
		elseif dy > 0 then
			player.currentAnimation = PlayerData.hasLamp and anims.lampDown or anims.down
		elseif dy < 0 then
			-- User provided 'up' (21-25) but no 'lampUp'? 
			-- Playdate code checks `PlayerData.hasLamp and ...` but didn't listing `lampUp` explicitly in the provided blocks?
			-- Wait, input says `lampIdle`, `lampRight`, `lampLeft`, `lampDown`. No `lampUp`.
			-- So for UP, we always use normal UP? Or flip down?
			-- Playdate logic: `self.animation:setState('idle')` (or lamp...)
			-- It doesn't seem to have directional logic in the 'init' block, that's just definitions.
			-- I will assume 'up' is shared or uses 'up'.
			player.currentAnimation = anims.up
		else
			player.currentAnimation = PlayerData.hasLamp and anims.lampIdle or anims.idle
		end
	end
end

return animations
