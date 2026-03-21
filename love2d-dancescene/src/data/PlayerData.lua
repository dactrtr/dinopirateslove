-- src/data/PlayerData.lua
-- Stub that mirrors the PlayerData global from source/assets/data/PlayerDataTables.lua.
-- Only the fields actually read/written by DanceScene are included.
-- Edit these values to test different difficulty scenarios.
PlayerData = {
    isDancing        = false,
    sanityCounter    = 0,       -- 0-100; higher = harder difficulty rolls
    calories         = 100,     -- 0-500
    amountDances     = 0,
    healedHP         = 2,
    healthPoints     = 10,
    canDance         = true,
    EnemiesData = {
        powerLevel   = 1,       -- 1-20; drives enemy type selection
        sightRadius  = 150,
        isEvolved    = false,
    },
    lastEnemyTouched = {
        id   = "test-enemy-001",
        type = "Brocorat",
        x    = 200,
        y    = 120,
    },
    playerSpawn = { x = 196, y = 116 },
    playerExit  = { x = 196, y = 116 },
    saveLevel   = 101,          -- room number to return to on win
}
