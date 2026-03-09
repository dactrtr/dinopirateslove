-- entities/CrewMember.lua
-- Ported from Playdate to Love2D
-- See DOCS/CREWMEMBER_CAPTURE_DEEP_DIVE.md for full spec
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local CrewMember = Class('CrewMember')

-- ---------------------------------------------------------------------------
-- Hat: sub-entidad separada, sin colisión, siempre 15px sobre el CM
-- ---------------------------------------------------------------------------
local Hat = {}
Hat.__index = Hat

function Hat.new(x, y)
	local self = setmetatable({}, Hat)
	self.x = x
	self.y = y
	self.visible = true
	return self
end

function Hat:moveTo(x, y)
	self.x = x
	self.y = y - 15
end

function Hat:setVisible(v)
	self.visible = v
end

function Hat:draw()
	-- Placeholder: dibuja un pequeño rectángulo amarillo si no hay asset
	if not self.visible then return end
	love.graphics.setColor(0.9, 0.8, 0.1, 1)
	love.graphics.rectangle("fill", self.x - 6, self.y - 4, 12, 6)
	love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- CrewMember
-- ---------------------------------------------------------------------------

function CrewMember:initialize(x, y, world, player, iid, data)
	-- x, y vienen del centro del sprite (LDtk)
	-- Convertimos a esquina superior-izquierda del sprite
	self.spriteWidth  = 48
	self.spriteHeight = 48
	self.x = x - self.spriteWidth  / 2
	self.y = y - self.spriteHeight / 2

	self.iid    = iid
	self.crewId = (data and data.customFields and data.customFields.crewId) or nil
	self.room   = (data and data.customFields and data.customFields.roomNumber) or nil
	self.sourceData = data or {}
	self.player = player
	self.world  = world

	-- Collision rect (offset desde esquina superior-izquierda del sprite)
	self.collideOffsetX = 12
	self.collideOffsetY = 24
	self.collideW = 24
	self.collideH = 24

	-- Registrar en BUMP
	self.inBumpWorld = false
	if world then
		world:add(self,
			self.x + self.collideOffsetX,
			self.y + self.collideOffsetY,
			self.collideW, self.collideH)
		self.inBumpWorld = true
	end

	-- Spritesheet y animaciones
	-- walk=1-4, idle=5-8, hide=12-13, stunned=15-18
	self.spritesheet = love.graphics.newImage('assets/images/enemies/crewmember-table-48-48.png')
	local imgW, imgH = self.spritesheet:getDimensions()
	local grid = anim8.newGrid(48, 48, imgW, imgH)
	local totalFrames = math.floor(imgW / 48) * math.floor(imgH / 48)

	-- Construir animaciones según frames disponibles
	local function safeAnim(startF, endF, dur)
		startF = math.min(startF, totalFrames)
		endF   = math.min(endF,   totalFrames)
		local frames = {}
		local cols = math.floor(imgW / 48)
		for i = startF, endF do
			local col = ((i - 1) % cols) + 1
			local row = math.ceil(i / cols)
			table.insert(frames, grid(col, row)[1])
		end
		if #frames == 0 then frames = {grid(1, 1)[1]} end
		return anim8.newAnimation(frames, dur)
	end

	self.animations = {
		walk    = safeAnim( 1,  4, 8/60),
		idle    = safeAnim( 5,  8, 6/60),
		hide    = safeAnim(12, 13, 6/60),
		stunned = safeAnim(15, 18, 6/60),
	}
	self.animState       = "idle"
	self.currentAnimation = self.animations.idle

	-- Hat
	self.hat = Hat.new(self.x + self.spriteWidth / 2, self.y)

	-- Movimiento (token budget)
	self.moveSpeed    = 1.5  -- px por frame activo
	self.movementFrames = 0

	-- Throttle: AI cada 2 frames
	self.updateFrameCounter = math.random(0, 1)

	-- Bounce system
	self.bounceFrames            = 0
	self.bounceDirection         = nil
	self.recentBounceCount       = 0
	self.bounceCountDecayFrames  = 0
	self.bouncesRequiredToHide   = 2
	self.BOUNCE_DECAY_RATE       = 30

	-- Hiding
	self.isHiding                    = false
	self.hidingTokensAccumulated     = 0
	self.hidingVisionRange           = 80
	self.hidingMovementTokensRequired = 3

	-- Stun
	self.isBlinded          = false
	self.blindFrames        = 0
	self.isStunnedInfinitely = false

	-- Flags
	self.isDead   = false
end

-- ---------------------------------------------------------------------------
-- Token budget
-- ---------------------------------------------------------------------------

function CrewMember:addMovementFrames(frames)
	if self.isHiding then
		self.hidingTokensAccumulated = self.hidingTokensAccumulated + (frames / 30)
		self:checkExitHiding()
	else
		self.movementFrames = math.min(self.movementFrames + frames, 90)
	end
end

function CrewMember:addMovementTokens(amount)
	if self.isHiding then
		self.hidingTokensAccumulated = self.hidingTokensAccumulated + amount
		self:checkExitHiding()
	else
		self.movementFrames = math.min(self.movementFrames + amount * 30, 90)
	end
end

-- ---------------------------------------------------------------------------
-- Stun / Blind
-- ---------------------------------------------------------------------------

function CrewMember:blind(frames)
	if self.isHiding then return end
	self.isBlinded      = true
	self.blindFrames    = frames or 60
	self.movementFrames = 0
	self.animState      = "idle"
end

function CrewMember:stunInfinite()
	self.isStunnedInfinitely = true
	self.movementFrames      = 0
	self.animState           = "stunned"
	self.hat:setVisible(false)
end

-- ---------------------------------------------------------------------------
-- Captura
-- ---------------------------------------------------------------------------

function CrewMember:taken()
	-- Marcar en levelsLDTK
	if levelsLDTK and self.room then
		for _, levelData in ipairs(levelsLDTK) do
			if levelData.customFields and levelData.customFields.roomNumber == self.room then
				if levelData.entities and levelData.entities.CrewMember then
					for _, crewData in ipairs(levelData.entities.CrewMember) do
						if crewData.iid == self.iid then
							if not crewData.customFields then crewData.customFields = {} end
							crewData.customFields.isTaken = true
							break
						end
					end
				end
				break
			end
		end
	end

	-- Actualizar PlayerData
	PlayerData.CrewMemberData.amountTaken = PlayerData.CrewMemberData.amountTaken + 1
	if self.crewId then
		PlayerData.CrewMemberData.idNumbers[self.crewId] = true
	end

	-- Restaurar plungerang SIEMPRE (doc sección 10)
	if self.player then
		self.player.hasProjectile = true
	end

	printDebug("🎯 CrewMember " .. tostring(self.iid) .. " capturado! Total: " .. PlayerData.CrewMemberData.amountTaken)

	-- Remover de BUMP y marcar muerto
	if self.inBumpWorld and self.world then
		self.world:remove(self)
		self.inBumpWorld = false
	end
	self.hat:setVisible(false)
	self.isDead = true
end

-- ---------------------------------------------------------------------------
-- AI: search → escape
-- ---------------------------------------------------------------------------

function CrewMember:isPlayerOutOfVision()
	if not self.player then return true end
	local cx = self.x + self.spriteWidth  / 2
	local cy = self.y + self.spriteHeight / 2
	local px = self.player.x
	local py = self.player.y
	local dist = math.sqrt((cx - px)^2 + (cy - py)^2)
	return dist > self.hidingVisionRange
end

function CrewMember:search()
	if not self:isPlayerOutOfVision() and not PlayerData.isTiny then
		self:escape()
	else
		self.animState = "idle"
	end
end

function CrewMember:escape()
	local goalX, goalY

	if self.bounceFrames > 0 then
		-- Modo bounce: moverse en la dirección asignada
		self.bounceFrames = self.bounceFrames - 1
		local dir = self.bounceDirection
		goalX = self.x + (dir == 'right' and self.moveSpeed or dir == 'left' and -self.moveSpeed or 0)
		goalY = self.y + (dir == 'down'  and self.moveSpeed or dir == 'up'   and -self.moveSpeed or 0)
		if self.bounceFrames <= 0 then self.bounceDirection = nil end
	else
		-- Modo normal: alejarse del player en ambos ejes (diagonal)
		local px, py = self.player.x, self.player.y
		local cx = self.x + self.spriteWidth  / 2
		local cy = self.y + self.spriteHeight / 2
		goalX = self.x + (px <= cx and self.moveSpeed or -self.moveSpeed)
		goalY = self.y + (py <= cy and self.moveSpeed or -self.moveSpeed)
	end

	self.animState = "walk"
	local blockedX, blockedY = self:moveAndDetectBlock(goalX, goalY)
	self:processBounce(blockedX, blockedY)
end

-- ---------------------------------------------------------------------------
-- Movimiento y detección de bloqueo
-- ---------------------------------------------------------------------------

function CrewMember:moveAndDetectBlock(goalX, goalY)
	local THRESHOLD = 0.5
	local goalCollX = goalX + self.collideOffsetX
	local goalCollY = goalY + self.collideOffsetY

	local actualCollX, actualCollY, cols, len = self.world:move(
		self, goalCollX, goalCollY,
		function(item, other) return CrewMember.collisionFilter(item, other) end
	)

	local actualX = actualCollX - self.collideOffsetX
	local actualY = actualCollY - self.collideOffsetY

	local blockedX = math.abs(actualX - goalX) > THRESHOLD
	local blockedY = math.abs(actualY - goalY) > THRESHOLD

	self.x = actualX
	self.y = actualY
	self.hat:moveTo(self.x + self.spriteWidth / 2, self.y)

	return blockedX, blockedY
end

function CrewMember.collisionFilter(item, other)
	if other.isWall or other.class and other.class.name == "Box" then
		return 'slide'
	elseif other.class and (other.class.name == "Enemy" or other.class.name == "Brocorat") then
		return 'slide'
	elseif other.isProp and not other.isMinifier then
		return 'slide'
	else
		return 'cross'
	end
end

-- ---------------------------------------------------------------------------
-- Sistema de rebotes
-- ---------------------------------------------------------------------------

function CrewMember:processBounce(blockedX, blockedY)
	-- Decay del contador
	if self.bounceCountDecayFrames > 0 then
		self.bounceCountDecayFrames = self.bounceCountDecayFrames - 1
	else
		self.recentBounceCount = 0
	end

	-- Solo registrar rebote si no hay rebote activo
	if (blockedX or blockedY) and self.bounceFrames <= 0 then
		self.recentBounceCount       = self.recentBounceCount + 1
		self.bounceCountDecayFrames  = self.BOUNCE_DECAY_RATE

		printDebug("🔄 CrewMember bounce " .. self.recentBounceCount .. "/" .. self.bouncesRequiredToHide)

		if self.recentBounceCount >= self.bouncesRequiredToHide then
			self:enterHiding()
			return
		end

		-- Calcular dirección perpendicular según posición relativa del player
		local cx = self.x + self.spriteWidth  / 2
		local cy = self.y + self.spriteHeight / 2
		local playerToLeft = self.player.x < cx
		local playerBelow  = self.player.y > cy

		if blockedX and blockedY then
			-- Esquina: elegir aleatoriamente entre perpendicular vertical u horizontal
			if math.random() > 0.5 then
				self.bounceDirection = playerBelow and 'up' or 'down'
			else
				self.bounceDirection = playerToLeft and 'right' or 'left'
			end
		elseif blockedX then
			self.bounceDirection = playerBelow and 'up' or 'down'
		elseif blockedY then
			self.bounceDirection = playerToLeft and 'right' or 'left'
		end

		self.bounceFrames = 20
	end
end

-- ---------------------------------------------------------------------------
-- Hiding
-- ---------------------------------------------------------------------------

function CrewMember:enterHiding()
	if self.isHiding then return end
	self.isHiding                = true
	self.hidingTokensAccumulated = 0
	self.animState               = "hide"
	self.hat:setVisible(false)

	-- Quitar del mundo de colisiones
	if self.inBumpWorld and self.world then
		self.world:remove(self)
		self.inBumpWorld = false
	end
	printDebug("🙈 CrewMember entró en hiding")
end

function CrewMember:checkExitHiding()
	if self:isPlayerOutOfVision()
	and self.hidingTokensAccumulated >= self.hidingMovementTokensRequired then
		self:exitHiding()
	end
end

function CrewMember:exitHiding()
	self.isHiding                = false
	self.hidingTokensAccumulated = 0
	self.animState               = "idle"
	self.hat:setVisible(true)
	self.bounceDirection = nil
	self.bounceFrames    = 0

	-- Restaurar en BUMP
	if not self.inBumpWorld and self.world then
		self.world:add(self,
			self.x + self.collideOffsetX,
			self.y + self.collideOffsetY,
			self.collideW, self.collideH)
		self.inBumpWorld = true
	end
	printDebug("🚶 CrewMember salió de hiding")
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function CrewMember:update(dt)
	if self.isDead then return end

	-- Throttle: incrementar contador cada frame
	self.updateFrameCounter = (self.updateFrameCounter + 1) % 2

	-- [1] Hiding: inmóvil, hat oculto, solo espera tokens
	if self.isHiding then
		self.animState = "hide"
		self.hat:setVisible(false)
		self.currentAnimation = self.animations.hide
		self.currentAnimation:update(dt)
		return
	end

	-- [2] Blinded: cuenta regresiva, sin movimiento
	if self.isBlinded then
		self.blindFrames = self.blindFrames - 1
		if self.blindFrames <= 0 then self.isBlinded = false end
		self.animState = "idle"
		self.currentAnimation = self.animations.idle
		self.currentAnimation:update(dt)
		return
	end

	-- [3] Stunned infinito: sin movimiento, hat oculto
	if self.isStunnedInfinitely then
		self.animState = "stunned"
		self.hat:setVisible(false)
		self.currentAnimation = self.animations.stunned
		self.currentAnimation:update(dt)
		return
	end

	-- [4] Movimiento con budget (AI cada 2 frames)
	if self.movementFrames > 0 then
		self.movementFrames = self.movementFrames - 1
		if self.updateFrameCounter == 0 then
			self:search()
		end
	else
		self.animState = "idle"
	end

	-- Actualizar animación según estado
	local targetAnim = self.animations[self.animState] or self.animations.idle
	if self.currentAnimation ~= targetAnim then
		self.currentAnimation = targetAnim
	end
	self.currentAnimation:update(dt)
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function CrewMember:draw(debug)
	if self.isDead then return end

	-- Hat siempre debajo del sprite
	self.hat:draw()

	if self.spritesheet and self.currentAnimation then
		self.currentAnimation:draw(self.spritesheet, self.x, self.y)
	else
		love.graphics.setColor(0.3, 0.7, 0.5, 0.8)
		love.graphics.rectangle("fill", self.x, self.y, self.spriteWidth, self.spriteHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end

	if debug and self.inBumpWorld then
		love.graphics.setColor(0, 1, 0.5, 0.4)
		love.graphics.rectangle("fill",
			self.x + self.collideOffsetX,
			self.y + self.collideOffsetY,
			self.collideW, self.collideH)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

return CrewMember
