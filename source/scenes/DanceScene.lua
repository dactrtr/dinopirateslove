-- scenes/DanceScene.lua
-- Love2D port of the rhythm combat scene.
-- Registered as "dance" in sceneManager. Reads enemy info from PlayerData.lastEnemyTouched.

local sceneManager = require 'sceneManager'
local Input = require 'assets.data.InputBindings'

require 'entities.UI.battle.ButtonPress'
require 'entities.UI.battle.HitZone'
require 'entities.UI.battle.PlayerDance'
require 'entities.UI.battle.EnemyRatDance'
require 'entities.UI.battle.BackgroundDance'
require 'entities.UI.battle.ButtonCover'
require 'entities.UI.battle.WinIndicator'
require 'entities.UI.battle.LoseIndicator'
require 'entities.UI.battle.ResultsScreen'
require 'utilities.balance'

local danceScene = {}

-- ── Screen layout constants (logical 400×240) ─────────────────────────────────
local SCREEN_CENTER_X = 200
local BAR_WIDTH       = 8
local BAR_HEIGHT      = 10
local BAR_Y           = 56

-- ── Enemy pattern profiles ────────────────────────────────────────────────────
local EnemyPatterns = {
    basic  = { weights = { arrows=0.8, aButton=0.2, bButton=0.0 }, phaseLength=10 },
    evolve = { weights = { arrows=0.6, aButton=0.2, bButton=0.2 }, phaseLength=10 },
    badass = { weights = { arrows=0.4, aButton=0.3, bButton=0.3 }, phaseLength=8  },
    boss   = { weights = { arrows=0.2, aButton=0.4, bButton=0.4 }, phaseLength=6  },
}

local function getPatternKey(profile)
    local w = profile.weights
    local rand = math.random()
    local sum = w.arrows + w.aButton + w.bButton
    local choice = rand * sum
    if choice < w.arrows then
        local arrows = {"leftButton","upButton","rightButton","downButton"}
        return arrows[math.random(#arrows)]
    elseif choice < w.arrows + w.aButton then
        return "aButton"
    else
        return "bButton"
    end
end

-- ── Difficulty helpers ────────────────────────────────────────────────────────
local function determineDifficultyUpgrade()
    local sanity   = PlayerData.sanityCounter or 0
    local power    = (PlayerData.EnemiesData and PlayerData.EnemiesData.powerLevel) or 0
    local calories = PlayerData.calories or 0
    local sN = math.max(0, math.min(1, sanity   / 100))
    local pN = math.max(0, math.min(1, power    / 20))
    local cN = math.max(0, math.min(1, calories / 500))
    return math.max(0, math.min(100, (sN*0.35 + pN*0.45 + cN*0.20) * 100))
end

local function determineEnemyType()
    local pwr = PlayerData.EnemiesData.powerLevel
    if pwr >= 1  and pwr <= 5  then return "basic"  end
    if pwr >= 6  and pwr <= 12 then return "evolve" end
    if pwr >= 13 and pwr <= 19 then return "badass" end
    if pwr == 20               then return "boss"   end
    return "basic"
end

-- ── Scene state (reset on each enter) ────────────────────────────────────────
local state = {}

local function resetState()
    state.bpm             = 16
    state.ButtonPressed   = nil
    state.accuracy        = 0
    state.totalAccuracy   = 0
    state.enemyHP         = 50
    state.evadePower      = 30
    state.condition       = nil
    state.enemyType       = nil
    state.enemyEvolving   = false
    state.numberOfButtons = 4
    state.balancePosition = 0
    state.balanceMaxOffset = state.enemyHP
    state.accuracyFrames  = 0
    state.correctButtonPresses = {
        aButton=0, bButton=0,
        leftButton=0, rightButton=0, upButton=0, downButton=0,
    }
    state.buttons          = {}
    state.hitZone          = nil
    state.playerDance      = nil
    state.enemyDance       = nil
    state.backgroundDance  = nil
    state.buttonCover      = nil
    state.winIndicator     = nil
    state.loseIndicator    = nil
    state.resultsScreen    = nil
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────
function danceScene.enter()
    math.randomseed(math.floor(love.timer.getTime() * 1000))
    resetState()

    PlayerData.isDancing = false

    -- Determine difficulty
    local chance = determineDifficultyUpgrade()
    local roll   = math.random(0, 100)
    if roll <= chance then
        state.enemyType = determineEnemyType()
        if state.enemyType == "basic"  then state.bpm=16; state.numberOfButtons=4  end
        if state.enemyType == "evolve" then state.bpm=24; state.numberOfButtons=6  end
        if state.enemyType == "badass" then state.bpm=28; state.numberOfButtons=8  end
        if state.enemyType == "boss"   then state.bpm=32; state.numberOfButtons=12 end
        state.enemyEvolving = true
    else
        state.enemyType     = "basic"
        state.enemyEvolving = false
        state.bpm           = 16
        state.numberOfButtons = 4
    end

    printDebug("DanceScene.enter: type=" .. state.enemyType .. " bpm=" .. state.bpm)

    -- Build buttons
    local startPoint  = 400
    local delayStep   = 300
    local profile     = EnemyPatterns[state.enemyType] or EnemyPatterns.basic
    local function kp() return getPatternKey(profile) end
    for i = 1, state.numberOfButtons do
        local b = ButtonPress.new(state.bpm, startPoint + state.bpm, kp)
        b:movementDelay((i-1) * delayStep)
        table.insert(state.buttons, b)
    end

    -- Build entities
    state.hitZone        = HitZone.new(40, 30, 10, 40)
    state.playerDance    = PlayerDance.new(state.bpm)
    state.enemyDance     = EnemyRatDance.new(state.bpm, state.enemyType, state.enemyEvolving)
    state.backgroundDance = BackgroundDance.new()
    state.buttonCover    = ButtonCover.new()
    state.winIndicator   = WinIndicator.new(SCREEN_CENTER_X + state.balanceMaxOffset + 2*BAR_WIDTH, BAR_Y + BAR_HEIGHT/2 - 6)
    state.loseIndicator  = LoseIndicator.new(SCREEN_CENTER_X - state.balanceMaxOffset - 2*BAR_WIDTH, BAR_Y + BAR_HEIGHT/2 - 6)
    state.resultsScreen  = ResultsScreen.new()
end

function danceScene.exit()
    PlayerData.isDancing = false
end

-- ── Update ────────────────────────────────────────────────────────────────────
function danceScene.update(dt)
    -- Always update visual elements (animations run during ready screen too)
    state.hitZone:update(dt)
    state.playerDance:update(dt)
    state.enemyDance:update(dt)

    -- Buttons scroll continuously (visible during ready screen)
    for _, btn in ipairs(state.buttons) do
        btn:update(dt)
    end

    -- Hit detection only runs during active battle
    if not PlayerData.isDancing then return end
    if state.condition ~= nil then return end

    -- Check buttons in hitzone
    local inZone = state.hitZone:overlapping(state.buttons)

    if #inZone > 0 then
        state.accuracyFrames = 0
        if state.ButtonPressed then
            local collisions = {}
            for _, btn in ipairs(inZone) do
                if btn.buttonKey == state.ButtonPressed then
                    collisions[#collisions+1] = btn
                end
            end

            if #collisions > 0 then
                -- Correct press
                collisions[1]:hit()
                state.accuracy = state.accuracy + 1
                state.totalAccuracy = state.totalAccuracy + 1
                if state.ButtonPressed == "aButton" or state.ButtonPressed == "bButton" then
                    state.balancePosition = Balance.applyABHit(state.balancePosition)
                    state.enemyDance:attackAnimation(state.ButtonPressed)
                else
                    state.balancePosition = Balance.applyArrowHit(state.balancePosition, state.accuracy)
                    state.playerDance:changeAnimation(state.ButtonPressed)
                end
            else
                -- Wrong press
                local wrongBtn = inZone[1]
                wrongBtn:hit()
                state.balancePosition = Balance.applyWrongPress(state.balancePosition)
            end
            state.ButtonPressed = nil
        end
    else
        state.accuracyFrames = state.accuracyFrames + 1
        state.balancePosition = Balance.applyMissPenalty(state.balancePosition, state.accuracyFrames)
        state.accuracy = 0
        state.ButtonPressed = nil
    end

    state.balancePosition = Balance.clamp(state.balancePosition, state.balanceMaxOffset)

    if Balance.isWin(state.balancePosition, state.balanceMaxOffset) then
        state.resultsScreen:win()
        PlayerData.isDancing = false
        state.condition = "win"
    end
    if Balance.isLose(state.balancePosition, state.balanceMaxOffset) then
        state.resultsScreen:lose()
        PlayerData.isDancing = false
        state.condition = "lose"
    end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────
function danceScene.draw()
    state.backgroundDance:draw(1)

    for _, btn in ipairs(state.buttons) do btn:draw(1) end

    state.hitZone:draw(1)
    state.buttonCover:draw(1)

    -- Balance bar
    local bx = SCREEN_CENTER_X + state.balancePosition - BAR_WIDTH/2
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill", bx, BAR_Y, BAR_WIDTH, BAR_HEIGHT)
    love.graphics.setColor(1, 1, 1)

    state.winIndicator:draw(1)
    state.loseIndicator:draw(1)
    state.playerDance:draw(1)
    state.enemyDance:draw(1)
    state.resultsScreen:draw(1)

    -- Debug
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(string.format("type=%s bpm=%d bal=%.1f",
        tostring(state.enemyType), state.bpm, state.balancePosition), 4, 4)
    love.graphics.setColor(1, 1, 1)
end

-- ── Input ─────────────────────────────────────────────────────────────────────
function danceScene.keypressed(key)
    -- Pre-battle: wait for AButton to start
    if not PlayerData.isDancing and state.condition == nil then
        if Input.is(key, "AButton") then
            danceScene.startBattle()
        end
        return
    end

    -- Post-result: press AButton to transition
    if state.condition ~= nil then
        if Input.is(key, "AButton") then
            danceScene.checkDanceResults()
        end
        return
    end

    -- Mid-battle: map key → button name (configurado en InputBindings.lua)
    local mapped = Input.danceKeys[key]
    if mapped then
        state.ButtonPressed = mapped
    end
end

function danceScene.keyreleased(key)
    state.ButtonPressed = nil
end

-- ── Game actions ──────────────────────────────────────────────────────────────
function danceScene.startBattle()
    state.resultsScreen:empty()
    PlayerData.isDancing = true
    state.enemyDance:setIdle()
end

function danceScene.checkDanceResults()
    local gameScene = require 'scenes.gameScene'
    if state.condition == "win" then
        state.condition     = nil
        state.totalAccuracy = 0
        gameScene.findAndKillEnemyById(PlayerData.lastEnemyTouched.id)
        PlayerData.healthPoints = math.min(
            PlayerData.healthPoints + (PlayerData.healedHP or 1),
            (Config.Player and Config.Player.maxHealth) or 3)
        PlayerData.calories     = (PlayerData.calories or 0) + 60
        PlayerData.amountDances = (PlayerData.amountDances or 0) + 1
        sceneManager.startTransition("dance", "game", "slide")

    elseif state.condition == "lose" then
        state.condition = nil
        sceneManager.startTransition("dance", "title", "slide")
    end
end

return danceScene
