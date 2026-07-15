-- utilities/conditionEval.lua
-- Pure Lua condition evaluator for Trigger and NPC conditionalScripts.
-- No LÖVE dependencies.
--
-- Supported syntax (evaluated against global PlayerData):
--   "true"          → always true
--   "path"          → PlayerData.path == true (boolean, nested with ".")
--   "!path"         → PlayerData.path ~= true (negated boolean)
--   "path>N"        → numeric comparison (also <, >=, <=, ==, !=)
--   "keys.N"        → PlayerData.keys[N] == true (integer-indexed)

local conditionEval = {}

local function resolvePath(root, path)
    local current = root
    for part in path:gmatch("[^%.]+") do
        if current == nil then return nil end
        local val = current[part]
        if val == nil then
            local numKey = tonumber(part)
            if numKey then val = current[numKey] end
        end
        current = val
    end
    return current
end

function conditionEval.condition(expr)
    if type(expr) ~= "string" then return false end
    if expr == "true" then return true end

    -- Numeric comparison: "path OP value"
    local path, op, valStr = expr:match("^([%w%.]+)%s*([<>!=]=?)%s*([%d%-%.]+)$")
    if path and op and valStr then
        local current
        if path == "crew" then
            -- Alias: total crew recruited, for story gating (mirrors Playdate trigger.lua)
            current = PlayerData.CrewMemberData and PlayerData.CrewMemberData.amountTaken
        else
            current = resolvePath(PlayerData, path)
        end
        local val        = tonumber(valStr)
        local currentVal = tonumber(current) or 0
        if     op == ">"  then return currentVal > val
        elseif op == "<"  then return currentVal < val
        elseif op == ">=" then return currentVal >= val
        elseif op == "<=" then return currentVal <= val
        elseif op == "==" then return currentVal == val
        elseif op == "!=" then return currentVal ~= val
        end
        return false
    end

    local invert    = false
    local cleanPath = expr
    if cleanPath:sub(1, 1) == "!" then
        invert    = true
        cleanPath = cleanPath:sub(2)
    end

    local value  = resolvePath(PlayerData, cleanPath)
    local result = (value == true)
    if invert then result = not result end
    return result
end

function conditionEval.evaluateTrigger(conditionalScripts)
    if not conditionalScripts then return nil, nil end
    for _, entry in ipairs(conditionalScripts) do
        local condExpr, rest = entry:match("^([^:]+):(.+)$")
        if condExpr and rest then
            local isTerminal = false
            local scriptName = rest
            if scriptName:sub(-1) == "!" then
                isTerminal = true
                scriptName = scriptName:sub(1, -2)
            end
            if conditionEval.condition(condExpr) then
                return scriptName, isTerminal
            end
        end
    end
    return nil, nil
end

function conditionEval.evaluateNPC(conditionalScripts)
    if not conditionalScripts then return nil, nil end
    for _, entry in ipairs(conditionalScripts) do
        local parts = {}
        for part in entry:gmatch("[^:]+") do parts[#parts + 1] = part end
        local condExpr   = parts[1]
        local scriptName = parts[2]
        local grantsStr  = nil
        if parts[3] and parts[4] then
            grantsStr = parts[3] .. ":" .. parts[4]
        end
        if condExpr and scriptName and conditionEval.condition(condExpr) then
            return scriptName, grantsStr
        end
    end
    return nil, nil
end

return conditionEval
