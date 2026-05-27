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
-- Extract necessary level data
-------------------------------------------------------------
function SaveSystem.getLevelState()
    local levelState = {}

    if not levelsLDTK then return levelState end

    for i, level in ipairs(levelsLDTK) do
        levelState[i] = {
            identifier = level.identifier,
            uniqueIdentifer = level.uniqueIdentifer,
            visited = level.customFields and level.customFields.visited or false,
            comic_wasPlayed = level.customFields and level.customFields.comic_wasPlayed or false,
            entities = {}
        }

        if level.entities then
            for entityType, entitiesList in pairs(level.entities) do
                levelState[i].entities[entityType] = {}

                for _, entity in ipairs(entitiesList) do
                    local entityState = {
                        iid = entity.iid
                    }

                    if entity.customFields then
                        -- Enemies
                        if entityType == "Brocorat" or entityType == "Bosscolli" then
                            entityState.dead = entity.customFields.dead or false
                            entityState.speed = entity.customFields.speed
                            entityState.x = entity.x
                            entityState.y = entity.y
                        end

                        -- Props
                        if entity.customFields.destroyed ~= nil then
                            entityState.destroyed = entity.customFields.destroyed
                        end

                        -- CrewMembers
                        if entityType == "CrewMember" then
                            entityState.isTaken = entity.customFields.isTaken or false
                            entityState.crewID = entity.customFields.crewID
                        end

                        -- Doors
                        if entityType == "Doors" then
                            entityState.isOpen   = entity.customFields.isOpen   or false
                            entityState.isLocked = entity.customFields.isLocked or false
                        end

                        -- Items
                        if entity.layer == "Items" then
                            entityState.collected = entity.customFields.collected or false
                        end

                        -- Triggers
                        if entity.customFields.type or entity.customFields.script or entity.customFields.usedTrigger ~= nil then
                            entityState.type = entity.customFields.type
                            entityState.script = entity.customFields.script
                            entityState.usedTrigger = entity.customFields.usedTrigger or false
                        end

                        -- NPCs
                        if entityType == "NPC" then
                            entityState.hasGranted = entity.customFields.hasGranted or false
                        end
                    end

                    table.insert(levelState[i].entities[entityType], entityState)
                end
            end
        end
    end

    return levelState
end

-------------------------------------------------------------
-- Restore level state
-------------------------------------------------------------
function SaveSystem.restoreLevelState(levelState)
    if not levelState or not levelsLDTK then return end

    for _, state in ipairs(levelState) do
        local targetIdx = nil
        
        -- Find level by uniqueIdentifer
        for j, level in ipairs(levelsLDTK) do
            if level.uniqueIdentifer == state.uniqueIdentifer then
                targetIdx = j
                break
            end
        end

        if targetIdx then
            local level = levelsLDTK[targetIdx]
            
            -- Restore simple fields
            if level.customFields then
                level.customFields.visited = state.visited
                level.customFields.comic_wasPlayed = state.comic_wasPlayed
            end

            if state.entities and level.entities then
                for entityType, savedEntities in pairs(state.entities) do
                    local targetList = level.entities[entityType]

                    -- Fallback for triggers
                    if not targetList and (entityType == "Triggers") then
                        for _, list in pairs(level.entities) do
                            if list[1] and list[1].layer == "Triggers" then
                                targetList = list
                                break
                            end
                        end
                    end

                    if targetList then
                        for _, savedEntity in ipairs(savedEntities) do
                            for _, currentEntity in ipairs(targetList) do
                                if currentEntity.iid == savedEntity.iid then
                                    if currentEntity.customFields then
                                        -- Enemies
                                        if savedEntity.dead ~= nil then currentEntity.customFields.dead = savedEntity.dead end
                                        if savedEntity.speed then currentEntity.customFields.speed = savedEntity.speed end
                                        if savedEntity.x and savedEntity.y then
                                            currentEntity.x = savedEntity.x
                                            currentEntity.y = savedEntity.y
                                        end

                                        -- Props
                                        if savedEntity.destroyed ~= nil then currentEntity.customFields.destroyed = savedEntity.destroyed end

                                        -- CrewMembers
                                        if savedEntity.isTaken ~= nil then currentEntity.customFields.isTaken = savedEntity.isTaken end

                                        -- Triggers
                                        if savedEntity.usedTrigger ~= nil then currentEntity.customFields.usedTrigger = savedEntity.usedTrigger end
                                        if savedEntity.type then currentEntity.customFields.type = savedEntity.type end
                                        if savedEntity.script then currentEntity.customFields.script = savedEntity.script end
                                        
                                        -- Doors
                                        if savedEntity.isOpen ~= nil then currentEntity.customFields.isOpen = savedEntity.isOpen end
                                        if savedEntity.isLocked ~= nil then currentEntity.customFields.isLocked = savedEntity.isLocked end

                                        -- Items
                                        if savedEntity.collected ~= nil then currentEntity.customFields.collected = savedEntity.collected end

                                        -- NPCs
                                        if savedEntity.hasGranted ~= nil then
                                            currentEntity.customFields.hasGranted = savedEntity.hasGranted
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------
-- Save logic for Love2D
-------------------------------------------------------------
function SaveSystem.save()
    if not PlayerData then
        printDebug("❌ SaveSystem: PlayerData is nil, cannot save!")
        return false
    end

    local saveData = {
        player = PlayerData,
        levelState = SaveSystem.getLevelState(),
        timestamp = os.time(),
        version = "2.0-LDTK"
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
    if saveData and saveData.version == "2.0-LDTK" then
        -- Update global PlayerData fields instead of replacing the reference
        -- This ensures other modules holding the reference stay in sync
        if not PlayerData then
            PlayerData = saveData.player
        else
            for k, v in pairs(saveData.player) do
                PlayerData[k] = v
            end
        end
        
        SaveSystem.restoreLevelState(saveData.levelState)
        printDebug("📖 SaveSystem: Game loaded successfully")
        return true, PlayerData.saveLevel
    end

    printDebug("⚠️ SaveSystem: Old save format detected or corrupted save")
    return false, nil
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
