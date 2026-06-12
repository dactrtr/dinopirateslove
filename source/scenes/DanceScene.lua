-- scenes/DanceScene.lua
-- Love2D port of the rhythm combat scene.
-- Registered as "dance" in sceneManager. Reads enemy info from PlayerData.lastEnemyTouched.

local sceneManager = require 'sceneManager'
local Input = require 'assets.data.InputBindings'
local SaveSystem = require 'SaveSystem'

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
danceScene.debugMode = false  -- Playdate: DanceScene.debugMode (forces basic, win exits to title)

local nudgeImage  -- balance bar sprite, loaded in enter()

-- Battle audio (lazy-loaded once; Playdate volumes: music 0.7, drums 0.8)
local battleMusic, kickSound, snareSound
local function loadAudio()
    if battleMusic then return end
    battleMusic = love.audio.newSource('assets/sounds/music/battle_music_test_ima.wav', 'stream')
    battleMusic:setLooping(true)
    battleMusic:setVolume(0.7)
    kickSound = love.audio.newSource('assets/sounds/music/drums/kick_test_ima.wav', 'static')
    kickSound:setVolume(0.8)
    snareSound = love.audio.newSource('assets/sounds/music/drums/snare_test_ima.wav', 'static')
    snareSound:setVolume(0.8)
end

-- Playdate: snare on A presses, kick on d-pad presses, B silent — only while dancing.
local function playInputSound(mapped)
    if not PlayerData.isDancing then return end
    if mapped == "aButton" then
        snareSound:stop(); snareSound:play()
    elseif mapped == "upButton" or mapped == "downButton"
        or mapped == "leftButton" or mapped == "rightButton" then
        kickSound:stop(); kickSound:play()
    end
end

-- ── Screen layout constants (logical 400×240) ─────────────────────────────────
local SCREEN_CENTER_X = 200
local BAR_WIDTH       = 8
local BAR_HEIGHT      = 10
local BAR_Y           = 56

-- Playdate locks DanceScene to 50 fps; all rhythm logic runs on this fixed tick.
local TICK = 1 / 50
local tickAccumulator = 0

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
    local pwr = (PlayerData.EnemiesData and PlayerData.EnemiesData.powerLevel) or 0
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
    state.condition       = nil
    state.enemyType       = nil
    state.enemyEvolving   = false
    state.numberOfButtons = 4
    state.balancePosition = 0
    state.balanceMaxOffset = state.enemyHP
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
    tickAccumulator = 0

    PlayerData.isDancing = false

    -- Determine difficulty
    if danceScene.debugMode then
        state.enemyType       = "basic"
        state.enemyEvolving   = false
        state.bpm             = Config.Dance.basic.bpm
        state.numberOfButtons = Config.Dance.basic.buttons
    else
        -- Decide whether to upgrade difficulty based on PlayerData
        local chance = determineDifficultyUpgrade()
        local roll   = math.random(0, 100)
        if roll <= chance then
            state.enemyType = determineEnemyType()
            local diffConfig = Config.Dance[state.enemyType] or Config.Dance.basic
            state.bpm             = diffConfig.bpm
            state.numberOfButtons = diffConfig.buttons
            state.enemyEvolving   = true
        else
            state.enemyType       = "basic"
            state.enemyEvolving   = false
            state.bpm             = Config.Dance.basic.bpm
            state.numberOfButtons = Config.Dance.basic.buttons
        end
    end

    printDebug("DanceScene.enter: type=" .. state.enemyType .. " bpm=" .. state.bpm)

    -- Build buttons (they freeze against each other instead of overlapping,
    -- replicating Playdate's moveWithCollisions 'freeze' response)
    local startPoint = 400
    local delayStep  = 300
    local profile    = EnemyPatterns[state.enemyType] or EnemyPatterns.basic
    local function kp() return getPatternKey(profile) end
    for i = 1, state.numberOfButtons do
        local b = ButtonPress.new(state.bpm, startPoint + state.bpm, kp)
        b:movementDelay((i-1) * delayStep)
        table.insert(state.buttons, b)
    end

    -- Build entities
    -- Playdate: HitZone centered at (40,30), 10×40 → top-left (35,10)
    state.hitZone        = HitZone.new(35, 10, 10, 40, state.bpm)
    state.playerDance    = PlayerDance.new(state.bpm)
    state.enemyDance     = EnemyRatDance.new(state.bpm, state.enemyType, state.enemyEvolving)
    state.backgroundDance = BackgroundDance.new()
    state.buttonCover    = ButtonCover.new()
    state.winIndicator   = WinIndicator.new(SCREEN_CENTER_X + state.balanceMaxOffset + 2*BAR_WIDTH, BAR_Y + BAR_HEIGHT/2 - 6)
    state.loseIndicator  = LoseIndicator.new(SCREEN_CENTER_X - state.balanceMaxOffset - 2*BAR_WIDTH, BAR_Y + BAR_HEIGHT/2 - 6)
    state.resultsScreen  = ResultsScreen.new()
    nudgeImage = nudgeImage or love.graphics.newImage('assets/images/ui/battle/nudgeIndicator.png')

    loadAudio()
    -- Playdate only has a track for the basic profile
    if state.enemyType == "basic" then
        battleMusic:play()
    end
end

function danceScene.exit()
    PlayerData.isDancing = false
    danceScene.debugMode = false
    -- Playdate parity: HP always resets to 2 when leaving the dance, win or
    -- lose. Yes, this discards the win-heal applied in checkDanceResults() —
    -- the original scene:exit() runs after it and does the same. Intentional;
    -- do not remove this reset to "fix" the heal.
    PlayerData.healthPoints = 2
    if battleMusic then battleMusic:stop() end
    SaveSystem.save()
end

-- One Playdate frame (1/50 s) of rhythm logic.
local function logicTick()
    -- Buttons move per tick, battle only (ButtonPress:tick gates on .active)
    if PlayerData.isDancing then
        for _, btn in ipairs(state.buttons) do
            btn:tick(state.buttons)
        end
    end

    -- Hit detection only runs during active battle
    if not PlayerData.isDancing then return end
    if state.condition ~= nil then return end

    local inZone = state.hitZone:overlapping(state.buttons)

    if #inZone > 0 then
        local btn = inZone[1]

        if state.ButtonPressed == nil then
            -- Button in zone, no key pressed: accuracy builds; drain past 5 frames
            state.accuracy = state.accuracy + 1
            if state.accuracy > Balance.MISS_GRACE_FRAMES then
                state.balancePosition = state.balancePosition + Balance.MISS_DELTA
            end
            state.enemyDance:changeAnimation(btn.buttonKey)

        elseif btn.buttonKey == state.ButtonPressed then
            -- Correct press
            if state.ButtonPressed == "aButton" or state.ButtonPressed == "bButton" then
                state.enemyDance:attackAnimation(state.ButtonPressed)
                state.balancePosition = Balance.applyABHit(state.balancePosition)
            else
                state.balancePosition = Balance.applyArrowHit(state.balancePosition, state.accuracy)
                state.totalAccuracy = state.totalAccuracy + state.accuracy
            end
            state.playerDance:changeAnimation(state.ButtonPressed)
            state.correctButtonPresses[state.ButtonPressed] = (state.correctButtonPresses[state.ButtonPressed] or 0) + 1
            btn:hit()

        else
            -- Wrong press
            btn:hit()
            state.balancePosition = Balance.applyWrongPress(state.balancePosition)
        end

        state.ButtonPressed = nil  -- consumed: one press counts once per tick

    else
        state.accuracy = 0
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

-- ── Update ────────────────────────────────────────────────────────────────────
function danceScene.update(dt)
    if not state.hitZone then return end

    dt = math.min(dt, 0.1)  -- cap tick debt after a hitch (window drag etc.)

    -- Visual animations advance in real time (ready screen included)
    state.hitZone:update(dt)
    state.playerDance:update(dt)
    state.enemyDance:update(dt)

    -- Stagger timers run in real time from enter() — Playdate starts them in
    -- scene:start(), i.e. they elapse during the ready screen too.
    for _, btn in ipairs(state.buttons) do
        btn:updateDelay(dt * 1000)
    end

    tickAccumulator = tickAccumulator + dt
    while tickAccumulator >= TICK do
        tickAccumulator = tickAccumulator - TICK
        logicTick()
    end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────
function danceScene.draw()
    if not state.backgroundDance then return end
    state.backgroundDance:draw(1)  -- z=1
    state.enemyDance:draw(1)        -- z=2

    for _, btn in ipairs(state.buttons) do btn:draw(1) end  -- z=4

    state.hitZone:draw(1)           -- z=5
    state.playerDance:draw(1)       -- z=6
    state.buttonCover:draw(1)       -- z=9

    -- Balance bar (z=9): Playdate drawCentered(nudgeIndicator, 200+pos-4, 56)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(nudgeImage,
        SCREEN_CENTER_X + state.balancePosition - BAR_WIDTH/2, BAR_Y,
        0, 1, 1, nudgeImage:getWidth()/2, nudgeImage:getHeight()/2)

    state.winIndicator:draw(1)      -- z=9
    state.loseIndicator:draw(1)     -- z=9
    state.resultsScreen:draw(1)     -- z=10

    -- Debug (Playdate only shows in debug mode)
    if danceScene.debugMode then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(string.format("type=%s bpm=%d bal=%.1f",
            tostring(state.enemyType), state.bpm, state.balancePosition), 4, 4)
        love.graphics.setColor(1, 1, 1)
    end
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
        playInputSound(mapped)
    end
end

function danceScene.keyreleased(key)
    state.ButtonPressed = nil
end

function danceScene.gamepadpressed(button)
    if not PlayerData.isDancing and state.condition == nil then
        if button == "a" then danceScene.startBattle() end
        return
    end
    if state.condition ~= nil then
        if button == "a" then danceScene.checkDanceResults() end
        return
    end
    local mapped = Input.dancePadButtons[button]
    if mapped then
        state.ButtonPressed = mapped
        playInputSound(mapped)
    end
end

function danceScene.gamepadreleased(button)
    state.ButtonPressed = nil  -- Playdate clears on any *ButtonUp
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

        if danceScene.debugMode then
            sceneManager.startTransition("dance", "title", "fade")
            return
        end

        gameScene.findAndKillEnemyById(PlayerData.lastEnemyTouched.id)
        PlayerData.healthPoints = math.min(
            PlayerData.healthPoints + (PlayerData.healedHP or 2),
            Config.Player.maxHealthPoints)
        -- Resume at the fight spot, not at a door
        PlayerData.playerSpawn.x   = PlayerData.playerExit.x
        PlayerData.playerSpawn.y   = PlayerData.playerExit.y
        PlayerData.returningInPlace = true
        PlayerData.amountDances = (PlayerData.amountDances or 0) + 1
        PlayerData.calories = math.min((PlayerData.calories or 0) + 60, Config.Dance.caloriesMax)
        sceneManager.startTransition("dance", "game", "fade")

    elseif state.condition == "lose" then
        state.condition = nil
        PlayerData.deathCause = "hp"  -- Playdate: lose the dance → "hp" death
        sceneManager.startTransition("dance", "dead", "fade")
    end
end

return danceScene
