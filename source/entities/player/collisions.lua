-- entities/player/collisions.lua
-- Collision-related functions for Player

local collisions = {}
local conditionEval = require 'utilities.conditionEval'

-- Get the collision box position and dimensions
function collisions.getCollisionRect(player)
	return player.x + player.collisionOffsetX, player.y + player.collisionOffsetY, player.width, player.height
end

-- Get the sprite position and dimensions (for drawing)
function collisions.getSpriteRect(player)
	return player.x, player.y, player.spriteWidth, player.spriteHeight
end

-- Update collision box position in BUMP world
function collisions.updateCollisionPosition(player)
	local collisionX = player.x + player.collisionOffsetX
	local collisionY = player.y + player.collisionOffsetY
	player.world:update(player, collisionX, collisionY, player.width, player.height)
end

-- Returns a table of colliding objects within the specified rectangle
-- @param x, y: top-left corner of the rectangle
-- @param w, h: width and height of the rectangle
-- @param filter: optional collision filter function
function collisions.collideRect(player, x, y, w, h, filter)
	local items, len = player.world:queryRect(x, y, w, h, filter)
	
	-- Format results similar to Playdate SDK
	local collisionList = {}
	for i = 1, len do
		local item = items[i]
		if item ~= player then -- Don't include self in collisions
			local itemX, itemY, itemW, itemH = player.world:getRect(item)
			table.insert(collisionList, {
				object = item,
				x = itemX,
				y = itemY,
				width = itemW,
				height = itemH
			})
		end
	end
	
	return collisionList, #collisionList
end

-- Check for collisions at the player's current collision box position
function collisions.checkCollisions(player)
	local collisionX, collisionY = player.x + player.collisionOffsetX, player.y + player.collisionOffsetY
	
	-- Debug query rect when tiny
	if PlayerData.isTiny then
		-- Only log once every few seconds for specific objects if needed, 
		-- but for diagnosis we'll log most collisions briefly
		-- printDebug("🔍 checkCollisions (Tiny): x="..collisionX..", y="..collisionY..", w="..player.width..", h="..player.height .. ", offX=" .. player.collisionOffsetX)
	end
	
	return collisions.collideRect(player, collisionX, collisionY, player.width, player.height)
end

-- Check for collisions at a specific sprite position (converts to collision box position)
function collisions.checkCollisionsAt(player, spriteX, spriteY)
	local collisionX = spriteX + player.collisionOffsetX
	local collisionY = spriteY + player.collisionOffsetY
	return collisions.collideRect(player, collisionX, collisionY, player.width, player.height)
end

-- Check for collisions in a specific direction from current position
function collisions.checkCollisionsInDirection(player, direction, distance)
	local checkX, checkY = player.x, player.y
	
	if direction == "up" then
		checkY = checkY - distance
	elseif direction == "down" then
		checkY = checkY + distance
	elseif direction == "left" then
		checkX = checkX - distance
	elseif direction == "right" then
		checkX = checkX + distance
	end
	
	return collisions.checkCollisionsAt(player, checkX, checkY)
end

-- Get all objects within a radius of the player (uses collision box center)
function collisions.getObjectsInRadius(player, radius)
	local centerX = player.x + player.collisionOffsetX + player.width / 2
	local centerY = player.y + player.collisionOffsetY + player.height / 2
	
	-- Create a square area around the player
	local x = centerX - radius
	local y = centerY - radius
	local w = radius * 2
	local h = radius * 2
	
	local collisionList, count = collisions.collideRect(player, x, y, w, h)
	
	-- Filter by actual distance for circular radius
	local filtered = {}
	for i = 1, count do
		local collision = collisionList[i]
		local objCenterX = collision.x + collision.width / 2
		local objCenterY = collision.y + collision.height / 2
		
		local distance = math.sqrt((centerX - objCenterX)^2 + (centerY - objCenterY)^2)
		if distance <= radius then
			collision.distance = distance
			table.insert(filtered, collision)
		end
	end
	
	return filtered, #filtered
end


-- Pure function for BUMP filters (no side effects)
function collisions.getType(player, other)
	if other.class and (other.class.name == "Enemy" or other.class.name == "Brocorat") then
		return 'cross'
	elseif other.class and other.class.name == "CrewMember" then
		return 'cross'
	elseif other.class and other.class.name == "Box" then
		return 'touch'
	elseif other.isTrigger then
		return 'cross'
	elseif other.isNPC then
		return 'cross'
	elseif other.isNPCWall then
		return 'touch'
	elseif other.class and other.class.name == 'Items' then
		return 'cross'
	elseif other.isProp then
		if other.isHole or other.isSlime or other.type == 'minifier' then
			return 'cross'
		elseif other.isTube then
			return PlayerData.isTiny and 'cross' or 'touch'
		end
		return 'touch'
	elseif other.class and other.class.name == "Door" then
		return 'cross'
	elseif other.isPortal then
		return 'cross'
	end

	return 'slide'
end

-- Side-effect and logic handling
function collisions.resolve(player, other)
	if other.class and (other.class.name == "Enemy" or other.class.name == "Brocorat") then
		-- Centralized so the enemy-side collision (Enemy:moveCollision) and the
		-- player-side collision (here) both run identical hit/dance/death logic.
		collisions.handleEnemyContact(player, other)

	elseif other.class and other.class.name == "CrewMember" then
		-- Tiny mode: just set as current trigger
		if PlayerData.isTiny then
			player.currentTrigger = other
		else
			-- Normal mode: capture the crewmember
			if PlayerData.CrewMemberData.amountTaken == 0 then
				-- Show special dialog on first capture
				if player.dialogUI then
					player.dialogUI:addScreen("gotcha", other.sourceFeed)
				end
			end
			if other.taken then other:taken(player) end
		end

	elseif other.isTrigger then
		local trigger = other
		if trigger.type == "Cutscene" then
			PlayerData.isGaming = false
			PlayerData.isCutscene = true
			if trigger.sourceData then
				if not trigger.sourceData.customFields then trigger.sourceData.customFields = {} end
				trigger.sourceData.customFields.usedTrigger = true
			end
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
			local comicData = comics and comics[trigger.script]
			if comicData then
				local ComicPlayer = require 'entities.UI.ComicPlayer'
				ComicPlayer.start(comicData, function()
					PlayerData.isGaming   = true
					PlayerData.isCutscene = false
				end)
			else
				printDebug("⚠️ Cutscene trigger: comic not found for key '" .. tostring(trigger.script) .. "'")
				PlayerData.isGaming   = true
				PlayerData.isCutscene = false
			end
		elseif trigger.type == "Search" or trigger.type == "Call" or trigger.type == nil then
			player.currentTrigger = trigger
		elseif trigger.type == "Story" then
			PlayerData.isGaming = false
			local script, isTerminal
			if trigger.conditionalScripts and #trigger.conditionalScripts > 0 then
				script, isTerminal = conditionEval.evaluateTrigger(trigger.conditionalScripts)
			end
			if not script then
				script     = trigger.script
				isTerminal = true
			end
			if player.dialogUI then player.dialogUI:addScreen(script) end
			if isTerminal and trigger.sourceData then
				if not trigger.sourceData.customFields then trigger.sourceData.customFields = {} end
				trigger.sourceData.customFields.usedTrigger = true
			end
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
		elseif trigger.type == "Counter" then
			PlayerData.storyCounter = (PlayerData.storyCounter or 0) + 1
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
		end

	elseif other.isNPC then
		player.currentTrigger = other

	elseif other.class and other.class.name == 'Items' then
		local item = other
		if item.type == 'keycard' then
			collisions.grabKey(player, item.keyNumber or 1)
			item:removeAll()
		elseif item.type == 'lamp' then
			collisions.grabLamp(player)
			item:removeAll()
		elseif item.type == 'radio' then
			collisions.grabRadio(player)
			item:removeAll()
		elseif item.type == 'notes' then
			collisions.grabNotes(player, item.grants)
			item:removeAll()
		elseif item.type == 'itemgift' or item.type == 'itemGift' then
			collisions.grabItemGift(player, item.grants)
			item:removeAll()
		elseif item.type == 'bag' or item.type == 'honk' then
			collisions.grabBag(player)
			item:removeAll()
		elseif item.type == 'tools' then
			collisions.grabTools(player)
			item:removeAll()
		elseif item.type == 'boots' then
			collisions.grabBoots(player)
			item:removeAll()
		elseif item.type == 'plunger' then
			collisions.grabPlunger(player)
			item:removeAll()
		end

	elseif other.isProp and other.isHole then
		if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
			local bat = Config and Config.Battery or {}
		collisions.drainBattery(player, PlayerData.isTiny and (bat.drainHoleTiny or 0.2) or (bat.drainHoleNormal or 0.5))
		else
			collisions.fallBelow(player)
		end
	
	elseif other.isProp and other.type == 'minifier' then
		player.currentMinifier = other
		PlayerData.readyToShrink = true

	elseif other.isProp and other.isTube then
		if PlayerData.isTiny == true then
			local tubeCenterX = other.x + 16
			if math.abs(player.x - tubeCenterX) < 10 then
				collisions.riseAbove(player)
			end
		end
	end
end

-- Backward compatibility wrapper for the filter
function collisions.response(player, other)
	return collisions.getType(player, other)
end

-- Procedural: vertical navigation regenerates the run. Falling through a hole starts a
-- fresh run entering via a "startdown" room (generator falls back to Start/normal); the
-- tube rises into a "startup" room. Meta-progression (items/skills/crew) persists in
-- PlayerData across the regenerated run. Returns true so the caller clears its latch.
function collisions.startVerticalRun(player, entryRole)
	if not RunState then
		printDebug("❌ vertical run failed: RunState unavailable")
		return false
	end
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if not gameScene then
		printDebug("❌ vertical run failed: gameScene unavailable")
		return false
	end
	-- Fresh run; no entry-door spawn carries over, so clear the door-cross hints.
	PlayerData.lastRoom = nil
	PlayerData.lastDoorCross = nil
	PlayerData.returningInPlace = false
	RunState.startRun(entryRole)
	-- Falling through a hole uses the custom fall animation; everything else
	-- (tube/rise, doors, portals) uses the default fade-to-black.
	if entryRole == "startdown" then
		gameScene.enterPendingNode("animated", "transitionFall")
	else
		gameScene.enterPendingNode()
	end
	return true
end

-- Returns true if a fall transition was queued, false otherwise
-- (caller uses this to clear the player's isFalling latch on failure).
function collisions.fallBelow(player)
	printDebug("🕳️ Player:fallBelow() -> new run (startdown)")
	return collisions.startVerticalRun(player, "startdown")
end

function collisions.riseAbove(player)
	printDebug("🚀 Player:riseAbove() -> new run (startup)")
	collisions.startVerticalRun(player, "startup")
end

function collisions.drainBattery(player, amount)
	local batteryFloor = (Config and Config.Battery and Config.Battery.floor) or 10
	PlayerData.battery = math.max(batteryFloor, PlayerData.battery - amount)
end

function collisions.startInvincibility(player, durationMs)
	player.isInvincible = true
	local Timer = require 'libraries/hump/timer'
	Timer.after(durationMs / 1000, function()
		player.isInvincible = false
	end)
end

function collisions.fight(player)
	local sceneManager = require 'sceneManager'
	PlayerData.amountDances = (PlayerData.amountDances or 0) + 1
	-- Save player exit position for return after battle
	PlayerData.playerExit = PlayerData.playerExit or {}
	PlayerData.playerExit.x = PlayerData.x
	PlayerData.playerExit.y = PlayerData.y
	printDebug("⚔️ fight() → transitioning to DanceScene")
	sceneManager.startTransition("game", "dance", "fade")
end

-- Centralized enemy-contact handler. Called from BOTH directions:
--   • player walks into an enemy  → collisions.resolve()
--   • enemy walks into the player → Enemy:moveCollision()
-- Faithful to the Playdate original: the rhythm Dance is a last-stand mechanic,
-- gated behind the canDance skill and a low-HP threshold. Without the skill,
-- enemies drain HP to death → DeadScene.
function collisions.handleEnemyContact(player, enemy)
	if player.isInvincible then return end

	PlayerData.lastEnemyTouched.type = enemy.enemyType or "Brocorat"
	PlayerData.lastEnemyTouched.id   = enemy.id
	PlayerData.lastEnemyTouched.x    = enemy.x
	PlayerData.lastEnemyTouched.y    = enemy.y

	PlayerData.healthPoints = math.max(0, PlayerData.healthPoints - (enemy.damage or 1))

	-- canDance is granted by the floor-4 Notes pickup (grabNotes → PlayerData.skills).
	local canDance = PlayerData.skills and PlayerData.skills.canDance
	enemyLog(string.format("contact id=%s dmg=%d → HP=%d  canDance=%s thr=%d",
		tostring(enemy.id), (enemy.damage or 1), PlayerData.healthPoints,
		tostring(canDance and true or false), (PlayerData.danceThresholdHP or 1)))
	if canDance and PlayerData.healthPoints < (PlayerData.danceThresholdHP or 1) then
		-- Near death and able to dance: enter the rhythm battle instead of dying.
		enemyLog("→ DANCE (fight)")
		collisions.fight(player)
	elseif PlayerData.healthPoints <= 0 then
		-- No dance skill (or threshold not reached): drained to death → game over.
		PlayerData.healthPoints = 0
		enemyLog("→ DEAD (caught)")
		collisions.dead(player, "caught")
	else
		enemyLog("→ knockback + invincibility")
		collisions.startInvincibility(player, (Config and Config.Invincibility and Config.Invincibility.duration) or 1000)
		collisions.applyKnockback(player, enemy.x, enemy.y)
	end
end

-- Push the player away from an enemy hit (ported from Player:applyKnockback).
function collisions.applyKnockback(player, enemyX, enemyY)
	local k = (Config and Config.Player and Config.Player.knockbackDistance) or 2
	local dx, dy = 0, 0
	if player.x ~= enemyX then dx = (player.x > enemyX) and k or -k end
	if player.y ~= enemyY then dy = (player.y > enemyY) and k or -k end
	if dx == 0 and dy == 0 then return end

	if player.world and player.world:hasItem(player) then
		local newCX = player.x + dx + (player.collisionOffsetX or 0)
		local newCY = player.y + dy + (player.collisionOffsetY or 0)
		local ax, ay = player.world:move(player, newCX, newCY, function() return 'slide' end)
		player.x = ax - (player.collisionOffsetX or 0)
		player.y = ay - (player.collisionOffsetY or 0)
	else
		player.x = player.x + dx
		player.y = player.y + dy
	end
end

-- Player death → game-over screen. Sets the cause shown by DeadScene.
function collisions.dead(player, cause)
	PlayerData.deathCause = cause or "caught"
	PlayerData.isGaming = false
	if player then player.isInvincible = true end  -- block further hits during transition
	local sceneManager = require 'sceneManager'
	printDebug("☠️ dead(" .. tostring(cause) .. ") → DeadScene")
	sceneManager.startTransition("game", "dead", "fade")
end

function collisions.startSliding(player, direction)
	if PlayerData.isSliding then return end

	local dx, dy = 0, 0
	if     direction == "up"    then dy = -1
	elseif direction == "down"  then dy =  1
	elseif direction == "left"  then dx = -1
	elseif direction == "right" then dx =  1
	else   return  -- nil or "idle" — no valid direction, don't slide
	end

	printDebug("🧊 startSliding(" .. tostring(direction) .. ")")
	player.slideExitFrames = false  -- cancel any lingering exit animation
	PlayerData.direction = direction
	PlayerData.isSliding = true
	player.slideDX = dx
	player.slideDY = dy
	-- Commit the slide direction. While the player stays on slime, input cannot
	-- re-steer the slide (cleared on wall hit or when leaving the slime entirely).
	player.committedSlideDir = direction
end

-- Grab helpers
function collisions.grabKey(player, num) PlayerData.keys[num] = true end
function collisions.grabLamp(player)
	PlayerData.items.hasLamp = true
	PlayerData.skills.canFlash = true
	local FXshadow = require 'entities.UI.FXshadow'
	FXshadow.markDirty()
end
function collisions.grabRadio(player) PlayerData.items.hasRadio = true end
function collisions.grabTools(player) PlayerData.items.hasTools = true end
function collisions.grabBoots(player) 
	PlayerData.items.hasBoots = true 
	PlayerData.skills.canDash = true
end
function collisions.grabPlunger(player) 
	PlayerData.items.hasPlunger = true 
	PlayerData.skills.canPlungerang = true
	PlayerData.activeItem = 3 -- Auto-equip plunger
	printDebug("🪠 Plunger collected and equipped!")
end
function collisions.grabBag(player) PlayerData.items.hasBag = true end

function collisions.grabNotes(player, grants)
	if grants then
		for key, val in grants:gmatch("([^:,]+):([^:,]+)") do
			local boolVal = (val == "true")
			PlayerData.skills[key] = boolVal
		end
	end
	PlayerData.items.hasNotes = true
end

function collisions.grabItemGift(player, grants)
	if grants then
		for key, val in grants:gmatch("([^:,]+):([^:,]+)") do
			local boolVal = (val == "true")
			PlayerData.items[key] = boolVal
		end
	end
end

return collisions
