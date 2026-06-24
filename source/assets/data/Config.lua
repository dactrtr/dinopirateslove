Config = {}

-- Rendering layers
Config.ZIndex = {
    player     = 4,
    enemy      = 3,
    props      = 2,
    items      = 4,
    foreground = 300,
    fx         = 1999,
    ui         = 2000,
    hud        = 2000,
    menu       = 2100,
    alert      = 2200,
}

-- Collision groups
Config.CollideGroups = {
    player     = 1,
    enemy      = 2,
    props      = 3,
    items      = 4,
    wall       = 5,
    noCollide  = 6,
    crewMember = 7,
}

-- Tilemap
Config.Tiles = {
    size     = 16,
    -- Tile IDs that are passable (everything else is treated as a solid wall)
    walkable = {0, 2, 3, 4, 32, 33},
    IntGrid = {
        wall         = 1,
        slime        = 2,
        hole         = 3,
        floor        = 4,
        tinyHole     = 32,
        grapplePoint = 33,   -- hookable + walkable tile for the grappling hook
    }
}

-- Player movement
Config.Player = {
    speed            = 2,
    maxHealthPoints         = 10,  -- hard cap on healthPoints (Playdate Config.Player.maxHealthPoints)
    speedDarkNoLamp  = 0.7,   -- multiplier when in darkness without lamp
    speedLowBattery  = 0.8,   -- multiplier when battery < batteryThresholdLow with lamp
    collideRect      = {x=8,  y=24, w=30, h=24},
    collideRectTiny  = {x=19, y=32, w=10, h=10},
    collideRectHead  = {x=8,  y=8, w=16, h=16},
    uiOffsetX        = 30,
    uiOffsetY        = 30,
    hudOffsetY       = -40,
    hudOffsetYTiny   = -17,
    triggerCheckDist        = 5,   -- px moved before re-checking triggers
    movementFramesPerAction = 3,   -- movement frames distributed to enemies/crew per discrete step
    movementStepDistance    = 3,   -- px the player must actually displace to count as one step/action
    feetOffsetY             = 12,  -- px from sprite position down to the player's feet (tile sampling / grapple landing)
    movementTokensPerAction = 5,   -- movement tokens granted to enemies/crew when a B-ability fires
    knockbackDistance       = 2,   -- px pushed on enemy hit
}

-- Grappling hook (charged plungerang)
Config.Grapple = {
    holdDelay       = 400,   -- ms holding B before the charge is "armed" (tap < this = plunge)
    minDistance     = 64,    -- px guaranteed on any armed release (~4 tiles)
    maxDistance     = 320,   -- px cap (~20 tiles)
    pixelsPerDegree = 0.4,   -- crank degrees -> launch distance
    projectileSpeed = 8,     -- px/frame the hook flies out / returns
    pullSpeed       = 8,     -- px/frame the player slides toward the tile
    cooldown        = 500,   -- ms between uses (reserved; NOT enforced, faithful to Playdate)
    ropeWidth       = 2,     -- px width of the rope drawn from player to hook
}

-- Dash ability
Config.Dash = {
    speed          = 6,
    totalDistance  = 56,
    bounceDistance = 16,
    batteryCost    = 10,
    cooldown       = 500,   -- ms
}

-- Slide (slime)
Config.Slide = {
    speed = 4,
}

-- Invincibility
Config.Invincibility = {
    duration    = 1000,  -- ms after being hit
    flickerRate = 100,   -- divides timer for blink effect
}

-- Battery
Config.Battery = {
    drainMovementDark = 0.5,   -- per frame moving in darkness
    drainHoleNormal   = 0.5,   -- per frame crossing a hole (normal size)
    drainHoleTiny     = 0.2,   -- per frame crossing a hole (tiny)

    -- Shared battery level thresholds used across Sanity, Enemy, and CrewMember systems
    thresholdCritical = 10,    -- critically low; enemies override speed, crew stops moving
    thresholdLow      = 20,    -- low; sanity drains faster, enemies slow down
    thresholdMid      = 60,    -- mid; enemies use reduced speed, crew restores movement
}

-- Sanity (drains in the dark, recovers in the light). Evaluated once per tick.
Config.Sanity = {
    -- ── Tick timing ──────────────────────────────────────────────────────────
    tickInterval         = 2000,  -- ms between sanity ticks (2000 = every 2 seconds)
    lossMultiplier       = 1,     -- global scale applied to every loss/gain below

    -- ── Sanity change per tick (multiplied by lossMultiplier) ────────────────
    lossLowBattery       = 2,     -- lost per tick in the dark with battery < batteryThresholdLow (or no lamp)
    lossMidBattery       = 1,     -- lost per tick in the dark with battery < batteryThresholdMid
    gainHighBattery      = 2,     -- gained per tick in the light, or in the dark with lamp + battery > batteryThresholdHigh

    -- ── Battery thresholds that select which case applies ────────────────────
    batteryThresholdLow  = Config.Battery.thresholdLow,  -- below this → fast drain (shared with Enemy)
    batteryThresholdMid  = 40,    -- below this → slow drain
    batteryThresholdHigh = 50,    -- above this → recover even in the dark (with lamp)

    focusCost            = 20,    -- sanity consumed by the focus ability
}

-- Light Burst (lamp ability)
Config.LightBurst = {
    batteryCost   = 10,
    minBattery    = 10,     -- minimum battery % required to use (just enough to cover batteryCost)
    cooldown      = 1000,   -- ms
    displayTime   = 1000,   -- ms the cone stays visible
    coneDistance  = 200,    -- px forward
    coneHeight    = 12,     -- scaling factor
    blindDuration = 60,     -- frames enemies stay blinded
    selfDamage    = 0,      -- HP the player loses each time the flash fires (0 = no self-damage)
}

-- Dark Reveal (lamp ability charged with the crank while holding B in darkness).
-- Burns the whole battery to flood the room with light for a few seconds.
Config.DarkReveal = {
    minBattery            = 80,    -- minimum battery % required to activate the reveal
    holdDelay             = 400,   -- ms holding B before the crank charge "arms" (tap < this = flash)
    crankThreshold        = 720,   -- degrees of total crank rotation required to activate
    revealDuration        = 3000,  -- ms the full light lasts after activation
    rechargeBlockDuration = 3000,  -- ms recharge is blocked after the reveal ends
    selfDamage            = 1,     -- HP the player loses each time the reveal fires (0 = no self-damage)
}

-- Projectile (plungerang)
Config.Projectile = {
    maxDistance   = 100,   -- px before returning
    speed         = 8,     -- px per frame
    blindDuration = 60,    -- frames enemies stay blinded on hit
}

-- Doors (screen positions and spawn offsets)
Config.Doors = {
    positions = {
        right = {x=393, y=122},
        left  = {x=4,   y=122},
        down  = {x=203, y=228},
        top   = {x=203, y=2  },
    },
    spawnCoords = {
        top   = {x=196, y=196},
        down  = {x=196, y=32 },
        right = {x=32,  y=116},
        left  = {x=364, y=116},
    },
    spawnInset = 32,   -- px the player spawns inward from the door it entered
    thickness  = 10,   -- generic thin-door depth (fallback door)
    span       = 56,   -- generic thin-door length (fallback door)
    plug = {           -- closed-door wall covers (§11)
        tilesheet  = 'assets/images/tile/tile-table-16-16',
        depthTiles = 1,
        trimTiles  = 1,
        tiles = { top = 44, down = 38, left = 42, right = 40 },
    },
}

-- Portal Doors
Config.Portals = {
    collideRect = {x=0, y=0, w=24, h=24},
}

-- Procedural run generation (see DOCS/PROCEDURAL_GENERATION.md §16)
Config.MapGen = {
    roomsBase         = 8,
    crewPerExtraRoom  = 1,
    roomsMax          = 20,
    roomsPerCrewSpawn = 4,
    utilityChance     = 0.4,
    totalCrew         = 12,
    enemyChance       = 0.6,
    itemChance        = 0.5,
    darkBiasPerCrew   = 0.02,
}

-- CrewMember AI
Config.CrewMember = {
    hatDelta                 = 15,
    hidingTokensRequired     = 3,
    hidingVisionRange        = 80,   -- px
    cornerDetectionThreshold = 0.5,  -- px
    bounceFrames             = 20,
    bounceCountDecayRate     = 30,   -- frames
    bouncesRequiredToHide    = 2,
    blindDuration            = 60,   -- frames
    framesPerToken           = 30,
    movementFramesCap        = 90,
    batteryThresholdStop     = Config.Battery.thresholdCritical,  -- shared with Enemy.batteryThresholdCritical
    batteryThresholdRestore  = Config.Battery.thresholdMid,       -- shared with Enemy.batteryThresholdMid
    collideRect              = {x=12, y=24, w=24, h=24},
}

-- Screen dimensions and random bounds
Config.Screen = {
    width         = 400,
    height        = 240,
    randomBoundsX = {min=20, max=380},
    randomBoundsY = {min=20, max=220},
}

-- Pedometer
Config.Pedometer = {
    stepsPerMovement = 0.5,
    stepsToTrigger   = 200,
    caloriesPerBurn  = 10,
}

-- Input
Config.Input = {
    crankMenuThreshold = 30,   -- degrees of crank rotation to navigate menu
}

-- In-game-menu procedural map (rendered by entities/UI/MapDrawer.lua)
Config.Map = {
    panel        = { x = 32, y = 18, w = 140, h = 75 }, -- rect on the menu image the map fits into
    maxCellSize  = 8,    -- cap on per-room box size
    cellGap      = 1,    -- gap between box and its grid cell edge
    lineWidth    = 1,    -- connection line width
    unvisitedAlpha = 0.35, -- alpha for unvisited boxes/edges (replaces Playdate dither)
    secretOffset = { col = 1, row = 0 }, -- cell offset for a visited secret node off its host
    roomColor    = { 1, 1, 1 },          -- room boxes + connection lines (white)
    markerColor  = { 0.196, 0.184, 0.161 }, -- current-room center dot (must contrast roomColor)
}

-- Enemy AI
Config.Enemy = {
    sightRadiusBase         = 150,  -- min 50; base detection radius stored in PlayerData.EnemiesData.sightRadius
    sightRadiusMin          = 50,
    sightRadiusPerPowerLevel = 3,   -- added to sightRadius per powerLevel point

    -- Move speed in darkness depending on player battery level
    moveSpeedBatteryEmpty   = 0.2,  -- absolute speed when player battery == 0 in darkness
    moveSpeedBatteryLow     = 0.5,  -- multiplier when battery <= batteryThresholdLow in darkness
    moveSpeedBatteryMid     = 0.7,  -- multiplier when battery <= batteryThresholdMid in darkness
    moveSpeedCritical       = 0.5,  -- absolute speed when battery < batteryThresholdCritical in darkness
    batteryThresholdLow      = Config.Battery.thresholdLow,      -- shared with Sanity.batteryThresholdLow
    batteryThresholdMid      = Config.Battery.thresholdMid,      -- shared with CrewMember.batteryThresholdRestore
    batteryThresholdCritical = Config.Battery.thresholdCritical, -- shared with CrewMember.batteryThresholdStop

    bounceFactor            = 3,    -- px pushed back on wall/prop/enemy collision
    eatPropPowerThreshold   = 25,   -- min powerLevel required for an enemy to eat an edible prop
    eatPropPowerPenalty     = 5,    -- powerLevel lost after eating a prop (cost of feeding)
    stunProcMultiplier      = 20,   -- multiplied by moveSpeed to compute stun threshold (enemy stops if below result)

    damage                  = 1,    -- HP removed from the player per contact
    knockbackDistance       = 16,   -- px the enemy is pushed back when hit by the plungerang

    -- Chase tuning (Love2D port). The enemy moves in real time at a fixed fraction
    -- of the player's own speed so the pursuit ratio stays constant regardless of
    -- how Config.Player.speed is tuned (classic Playdate feel: only catches you if
    -- you corner yourself or stop).
    chaseSpeedRatio         = 0.15, -- enemy chase speed as a fraction of the player's speed (Playdate-faithful: enemy moved moveSpeed/3 px per frame ≈ 15% of the player)
    ldtkSpeedBaseline       = 0.5,  -- legacy Playdate px/frame value treated as 100% (LDtk `speed` customField)
    maxStepDt               = 1/30, -- dt clamp per tick; stops a frame-hitch spike from teleporting the enemy

    -- Turn-based token budget. The player feeds movementFramesPerAction frames per
    -- step (see Config.Player.movementStepDistance); the enemy spends 1/frame while
    -- pursuing. A SMALL cap is what makes the enemy stop almost immediately when the
    -- player stops (cap frames = residual chase, e.g. 6 frames ≈ 0.1 s at 60 fps).
    movementFramesCap       = 6,    -- max frames an enemy can bank (residual movement after the player stops)

    -- Hole detection (holes are tiles, not bump colliders, so the enemy probes them
    -- directly to avoid walking across gaps the player would fall into).
    holeProbeFeetInset      = 6,    -- px up from the sprite bottom where the "feet" are sampled
    holeProbeHalfWidth      = 8,    -- half-width of the 3-point feet sample (left / center / right)
}

-- Dance (rhythm combat)
Config.Dance = {
    basic  = { bpm = 16, buttons = 4  },
    evolve = { bpm = 24, buttons = 6  },
    badass = { bpm = 28, buttons = 8  },
    boss   = { bpm = 32, buttons = 12 },

    -- Normalization maxima for difficulty roll inputs
    sanityMax   = 100,  -- assumed sanityCounter ceiling for normalization
    powerMax    = 20,   -- assumed powerLevel ceiling for normalization (matches PlayerData max)
    caloriesMax = 500,  -- assumed calories ceiling for normalization

    -- Weights for the weighted difficulty upgrade roll (must sum to 1.0)
    weightSanity   = 0.35,  -- contribution of sanityCounter to upgrade probability
    weightPower    = 0.45,  -- contribution of powerLevel to upgrade probability
    weightCalories = 0.20,  -- contribution of calories to upgrade probability
}

-- Cockpit scene
Config.Cockpit = {
    lerpFactor       = 0.15,  -- pointer smoothing (0=frozen, 1=instant)
    accelSensitivity = 2.0,   -- multiplier on raw accelerometer tilt
    pointerRadius    = 6,     -- circle radius in px
    dpadSpeed        = 3,     -- pixels per frame when moving with d-pad
    failLimit        = 10,    -- max wrong button presses before returning to TitleScene
}

Config.Space = {
    crosshairSpeed        = 4,
    lerpFactor            = 0.08,
    accelSensitivity      = 1.2,
    shipMoveLerp          = 0.12,
    accelIdleThreshold    = 0.005,
    accelIdleFrames       = 2,
    accelCenterReturnLerp = 0.04,

    -- speed & danger
    speedDecay            = 0.05,
    maxSpeed              = 20,
    minSpeed              = 3,
    dangerFillRate        = 0.002,
    dangerDrainRate       = 0.003,

    -- meteorite pools
    meteoriteNearCount    = 14,
    meteoriteFarCount     = 10,
    meteoriteNearSpeed    = 3,
    meteoriteFarSpeed     = 1.5,
    meteoriteSpeedMult    = 0.2,
    parallaxSpeed         = 3,
    meteoriteFarParallax  = 0.5,
    meteoriteFarScale     = 0.6,

    -- collision
    invincibilityFrames   = 60,
    collisionZoneStart    = 0.90,  -- 0-1; meteorite must be this far into its approach before collision is live

    -- hit shake
    shakeFrames           = 25,    -- frames the shake lasts
    shakeMagnitude        = 6,     -- max px offset at start of shake (decays to 0)
}

return Config
