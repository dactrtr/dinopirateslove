-- source/SaveSystem.lua
-- Ported from Playdate to Love2D
local SaveSystem = {}
-- PlayerData is global

-- Helper function for deep copying tables (already in PlayerDataTables, but re-defined here for autonomy if needed)
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Global variable for original level data backup
levelsLDTKOriginal = nil

-------------------------------------------------------------
-- Save logic for Love2D
-------------------------------------------------------------
-- Capture the player's live position into PlayerData.playerSpawn so a later save resumes
-- exactly where the run was left (mirrors Playdate's MazeScene captureResumePosition).
-- Together with returningInPlace in titleScene's Continue, computeSpawn honours this
-- position instead of a door spawn.
--
-- Deliberately NOT called from inside SaveSystem.save() itself: save() also runs
-- mid-door/portal-transition (gameScene.exit()), at which point a portal or DanceScene
-- may have already staged PlayerData.playerSpawn for the destination room — capturing the
-- live (pre-transition, old-room) position there would clobber that. Playdate only calls
-- this on scene:pause() (menu/sleep), never on scene:finish(); call sites here should do
-- the same — only where the player is genuinely idle mid-room, not mid-transition.
function SaveSystem.captureResumePosition()
    local gs = require('sceneManager').getScene("game")
    if gs and gs.player and PlayerData and PlayerData.playerSpawn then
        PlayerData.playerSpawn.x = gs.player.x
        PlayerData.playerSpawn.y = gs.player.y
    end
end

function SaveSystem.save()
    if not PlayerData then
        printDebug("❌ SaveSystem: PlayerData is nil, cannot save!")
        return false
    end

    local saveData = {
        version = "3.0-PROCGEN",
        player  = PlayerData,
        run     = (RunState and RunState.serialize()) or nil,
        timestamp = os.time(),
    }

    local content = "return " .. SaveSystem.serializeTable(saveData)
    local filename = "gameState.lua"
    
    local success, message = love.filesystem.write(filename, content)
    if success then
        printDebug("💾 SaveSystem: Game saved successfully to " .. love.filesystem.getSaveDirectory() .. "/" .. filename)
        return true
    else
        printDebug("❌ SaveSystem: Failed to save game: " .. tostring(message))
        return false
    end
end

-------------------------------------------------------------
-- Load logic for Love2D
-------------------------------------------------------------
function SaveSystem.load()
    local filename = "gameState.lua"
    if not love.filesystem.getInfo(filename) then
        printDebug("🔭 SaveSystem: No save file found at " .. filename)
        return false, nil
    end

    -- Load via chunk (since we saved as 'return { ... }')
    local chunk, err = love.filesystem.load(filename)
    if not chunk then
        printDebug("❌ SaveSystem: Error loading save file: " .. tostring(err))
        return false, nil
    end

    local saveData = chunk()
    if not saveData or saveData.version ~= "3.0-PROCGEN" then
        printDebug("⚠️ SaveSystem: rejecting non-3.0 save (offer New Game)")
        return false, nil
    end

    -- Update global PlayerData fields instead of replacing the reference, so other
    -- modules holding the reference stay in sync.
    if saveData.player then
        if not PlayerData then
            PlayerData = saveData.player
        else
            for k, v in pairs(saveData.player) do
                PlayerData[k] = v
            end
        end
    end

    -- Rebuild the active run; deserialize stages currentNodeId as pending so the next
    -- gameScene.enter lands on the saved room.
    if RunState and saveData.run then
        if not RunState.deserialize(saveData.run) then
            printDebug("⚠️ SaveSystem: RunState.deserialize failed (run unrecoverable)")
            return false, nil
        end
    end

    printDebug("📖 SaveSystem: Game loaded successfully (3.0-PROCGEN)")
    return true, PlayerData.saveLevel
end

-------------------------------------------------------------
-- Reset
-------------------------------------------------------------
function SaveSystem.reset()
    if ResetPlayerData then
        ResetPlayerData()
    else
        printDebug("⚠️ SaveSystem: ResetPlayerData function not found!")
    end
    
    if levelsLDTKOriginal then
        -- We must update the GLOBAL levelsLDTK
        levelsLDTK = deepcopy(levelsLDTKOriginal)
    else
        printDebug("⚠️ SaveSystem: Original levels backup not found!")
    end
    printDebug("🔄 SaveSystem: Game state reset")
end

-------------------------------------------------------------
-- Delete
-------------------------------------------------------------
function SaveSystem.delete()
    local filename = "gameState.lua"
    local success, err = love.filesystem.remove(filename)

    if success then
        printDebug("🗑️ SaveSystem: Save deleted successfully")
    else
        -- File didn't exist or couldn't be removed — still reset in-memory state
        printDebug("⚠️ SaveSystem: Could not delete save file: " .. tostring(err))
    end

    SaveSystem.reset()
    return success
end

-------------------------------------------------------------
-- Backup original level data
-------------------------------------------------------------
function SaveSystem.createOriginalBackup()
    if not levelsLDTKOriginal and levelsLDTK then
        levelsLDTKOriginal = deepcopy(levelsLDTK)
    end
end

-------------------------------------------------------------
-- Simple Table Serializer (Helper)
-------------------------------------------------------------
function SaveSystem.serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)
    if name then tmp = tmp .. (type(name) == "number" and "[" .. name .. "]" or "['" .. tostring(name) .. "']") .. " = " end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp = tmp .. SaveSystem.serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "nil"
    end

    return tmp
end

return SaveSystem
