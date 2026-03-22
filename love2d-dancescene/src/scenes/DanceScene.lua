-- src/scenes/DanceScene.lua
-- Port of Playdate DanceScene. Reference: source/scenes/DanceScene.lua

local SCALE = 2  -- logical 400×240 → physical 800×480

-- Require all entities and logic
require "src/data/PlayerData"
require "src/data/EnemyPatterns"
require "src/logic/balance"
require "src/entities/ButtonPress"
require "src/entities/HitZone"
require "src/entities/PlayerDance"
require "src/entities/EnemyRatDance"
require "src/entities/BackgroundDance"
require "src/entities/ButtonCover"
require "src/entities/WinIndicator"
require "src/entities/LoseIndicator"
require "src/entities/ResultsScreen"
require "src/scenes/TitleScene"

DanceScene = {}
DanceScene.__index = DanceScene

-- Stub: replace with real enemy-kill logic when integrating with MazeScene
local function findAndKillEnemyById(id)
    print("[DanceScene] killed enemy: " .. tostring(id))
end

-- ─────────────────────────────────────────────
-- Difficulty helpers (verbatim logic from original)
-- ─────────────────────────────────────────────

local function determineDifficultyUpgrade()
    local sanity   = PlayerData.sanityCounter or 0
    local power    = (PlayerData.EnemiesData and PlayerData.EnemiesData.powerLevel) or 0
    local calories = PlayerData.calories or 0
    local sN = math.max(0, math.min(1, sanity   / 100))
    local pN = math.max(0, math.min(1, power    / 20))
    local cN = math.max(0, math.min(1, calories / 500))
    local score = sN * 0.35 + pN * 0.45 + cN * 0.20
    return math.max(0, math.min(100, score * 100))
end

local function determineEnemyType()
    local pwr = PlayerData.EnemiesData.powerLevel
    if pwr >= 1  and pwr <= 5  then return "basic"  end
    if pwr >= 6  and pwr <= 12 then return "evolve" end
    if pwr >= 13 and pwr <= 19 then return "badass" end
    if pwr == 20               then return "boss"   end
    return "basic"
end

-- ─────────────────────────────────────────────
-- Scene lifecycle
-- ─────────────────────────────────────────────

function DanceScene.new()
    local self = setmetatable({}, DanceScene)

    math.randomseed(math.floor(love.timer.getTime() * 1000))

    -- State (mirrors Playdate init)
    self.bpm                 = 16
    self.ButtonPressed       = nil
    self.accuracy            = 0
    self.totalAccuracy       = 0
    self.enemyHP             = 50
    self.evadePower          = 30
    self.condition           = nil
    self.enemyType           = nil
    self.enemyEvolving       = false
    self.numberOfButtons     = 4
    self.balancePosition     = 0
    self.balanceMaxOffset    = self.enemyHP  -- mirrors original: self.balanceMaxOffset = self.enemyHP
    self.correctButtonPresses = {
        aButton=0, bButton=0,
        leftButton=0, rightButton=0, upButton=0, downButton=0,
    }

    -- Screen constants (logical coords)
    self.screenCenterX = 200
    self.barWidth      = 8
    self.barHeight     = 10
    self.barY          = 56

    return self
end

function DanceScene:enter()
    PlayerData.isDancing = false
    self.condition       = nil

    -- Difficulty roll (exact logic from original)
    local chance = determineDifficultyUpgrade()
    local roll   = math.random(0, 100)

    if roll <= chance then
        self.enemyType    = determineEnemyType()
        self.enemyEvolving = true
    else
        self.enemyType    = "basic"
        self.enemyEvolving = false
    end

    -- BPM + button count by type
    local cfg = {
        basic  = { bpm=16, buttons=4  },
        evolve = { bpm=24, buttons=6  },
        badass = { bpm=28, buttons=8  },
        boss   = { bpm=32, buttons=12 },
    }
    local c = cfg[self.enemyType] or cfg.basic
    self.bpm             = c.bpm
    self.numberOfButtons = c.buttons

    -- Create ButtonPress instances — two-phase: create all at startPoint, then stagger delays.
    local startPoint = 400
    local profile    = EnemyPatterns[self.enemyType] or EnemyPatterns.basic
    local function keyProvider() return getPatternKey(profile) end

    self.buttons = {}
    for i = 1, self.numberOfButtons do
        local btn = ButtonPress.new(self.bpm, startPoint, keyProvider)
        btn:movementDelay((i - 1) * 300)  -- stagger: 0ms, 300ms, 600ms, ...
        self.buttons[i] = btn
    end

    -- Create all other entities (positions match plan)
    self.hitZone         = HitZone.new(30, 100, 20, 40)
    self.playerDance     = PlayerDance.new(self.bpm)
    self.enemyDance      = EnemyRatDance.new(self.bpm, self.enemyType, self.enemyEvolving)
    self.buttonCover     = ButtonCover.new()
    self.winIndicator    = WinIndicator.new(self.screenCenterX + self.balanceMaxOffset + 2*self.barWidth,
                                            self.barY + self.barHeight/2 - 6)
    self.loseIndicator   = LoseIndicator.new(self.screenCenterX - self.balanceMaxOffset - 2*self.barWidth,
                                             self.barY + self.barHeight/2 - 6)
    self.backgroundDance = BackgroundDance.new()
    self.resultsScreen   = ResultsScreen.new()
end

function DanceScene:exit()
    PlayerData.healthPoints = 2  -- mirrors Playdate DanceScene:exit() side effect
end

-- ─────────────────────────────────────────────
-- Update (core game loop — mirrors original update())
-- ─────────────────────────────────────────────

function DanceScene:update(dt)
    -- Pre-battle: waiting for player to press A
    if not PlayerData.isDancing and self.condition == nil then
        self.resultsScreen:loadingScreen()
        return
    end

    -- Update all button positions
    for _, btn in ipairs(self.buttons or {}) do
        btn:update(dt)
    end

    -- HitZone collision check (replaces overlappingSprites)
    local collisions = self.hitZone:overlapping(self.buttons)

    if #collisions > 0 then
        if self.ButtonPressed == nil then
            -- No input: accuracy penalty after grace frames
            self.accuracy = self.accuracy + 1
            self.balancePosition = Balance.applyMissPenalty(self.balancePosition, self.accuracy)
            self.enemyDance:changeAnimation(collisions[1].buttonKey)

        elseif collisions[1].buttonKey == self.ButtonPressed then
            -- Correct press
            if self.ButtonPressed == "aButton" or self.ButtonPressed == "bButton" then
                self.enemyDance:attackAnimation(self.ButtonPressed)
                self.enemyHP         = self.enemyHP - 10
                self.balancePosition = Balance.applyABHit(self.balancePosition)
            else
                -- Arrow: accuracy-based balance gain
                self.balancePosition = Balance.applyArrowHit(self.balancePosition, self.accuracy)
                self.totalAccuracy   = self.totalAccuracy + self.accuracy
                self.evadePower      = self.totalAccuracy
            end
            self.playerDance:changeAnimation(self.ButtonPressed)
            collisions[1]:hit()
            self:incrementCorrectPress(self.ButtonPressed)
        else
            -- Wrong press
            collisions[1]:hit()
            self.balancePosition = Balance.applyWrongPress(self.balancePosition)
        end
        self.ButtonPressed = nil
    else
        self.accuracy = 0
    end

    -- Clamp balance
    self.balancePosition = Balance.clamp(self.balancePosition, self.balanceMaxOffset)

    -- Win / lose threshold check
    if Balance.isWin(self.balancePosition, self.balanceMaxOffset) then
        self.resultsScreen:win()
        PlayerData.isDancing = false
        self.condition = "win"
    end
    if Balance.isLose(self.balancePosition, self.balanceMaxOffset) then
        self.resultsScreen:lose()
        PlayerData.isDancing = false
        self.condition = "lose"
    end
end

-- ─────────────────────────────────────────────
-- Draw
-- ─────────────────────────────────────────────

function DanceScene:draw()
    self.backgroundDance:draw(SCALE)

    -- Draw buttons
    for _, btn in ipairs(self.buttons or {}) do
        btn:draw(SCALE)
    end

    -- Draw HitZone
    self.hitZone:draw(SCALE)
    self.buttonCover:draw(SCALE)

    -- Balance bar (yellow rectangle placeholder)
    local bx = (self.screenCenterX + self.balancePosition - self.barWidth/2) * SCALE
    local by = self.barY * SCALE
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill", bx, by, self.barWidth * SCALE, self.barHeight * SCALE)
    love.graphics.setColor(1, 1, 1)

    -- Indicators
    self.winIndicator:draw(SCALE)
    self.loseIndicator:draw(SCALE)

    -- Dancer sprites
    self.playerDance:draw(SCALE)
    self.enemyDance:draw(SCALE)

    -- Results overlay (drawn last, on top)
    self.resultsScreen:draw(SCALE)

    -- Debug info
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(
        string.format("type=%s bpm=%d bal=%.1f hp=%d",
            tostring(self.enemyType), self.bpm,
            self.balancePosition, self.enemyHP),
        4, 4)
    love.graphics.setColor(1, 1, 1)
end

-- ─────────────────────────────────────────────
-- Input (replaces Noble inputHandler table)
-- ─────────────────────────────────────────────

function DanceScene:keypressed(key)
    -- Pre-battle start (mirrors AButtonDown when isDancing==false)
    if not PlayerData.isDancing and self.condition == nil then
        if key == "return" or key == "space" then
            self:startBattle()
        end
        return
    end

    -- Map keyboard → button keys
    local keyMap = {
        ["return"] = "aButton",
        ["space"]  = "aButton",
        ["lshift"] = "bButton",
        ["rshift"] = "bButton",
        ["left"]   = "leftButton",
        ["right"]  = "rightButton",
        ["up"]     = "upButton",
        ["down"]   = "downButton",
    }
    local mapped = keyMap[key]
    if mapped then
        self:danceStep(mapped)
        -- Only A-button (return/space) can trigger scene transition.
        -- Mirrors original: only AButtonDown calls checkDanceResults().
        if key == "return" or key == "space" then
            self:checkDanceResults()
        end
    end
end

function DanceScene:keyreleased(key)
    self:clearButton()
end

-- ─────────────────────────────────────────────
-- Game actions (verbatim from original)
-- ─────────────────────────────────────────────

function DanceScene:danceStep(inputStep)
    self.ButtonPressed = inputStep
end

function DanceScene:clearButton()
    self.ButtonPressed = nil
end

function DanceScene:incrementCorrectPress(button)
    if self.correctButtonPresses[button] ~= nil then
        self.correctButtonPresses[button] = self.correctButtonPresses[button] + 1
    end
end

function DanceScene:startBattle()
    self.resultsScreen:empty()
    PlayerData.isDancing = true
    self.enemyDance:setIdle()
end

function DanceScene:checkDanceResults()
    if self.condition == "win" then
        self.condition     = nil
        self.totalAccuracy = 0
        findAndKillEnemyById(PlayerData.lastEnemyTouched.id)
        PlayerData.healthPoints   = PlayerData.healthPoints + PlayerData.healedHP
        PlayerData.playerSpawn.x  = PlayerData.playerExit.x
        PlayerData.playerSpawn.y  = PlayerData.playerExit.y
        PlayerData.amountDances   = PlayerData.amountDances + 1
        PlayerData.calories       = PlayerData.calories + 60
        print("[DanceScene] WIN — would return to room " .. PlayerData.saveLevel)
        SceneManager.switch(TitleScene.new())

    elseif self.condition == "lose" then
        self.condition = nil
        print("[DanceScene] LOSE — game over")
        SceneManager.switch(TitleScene.new())
    end
end
