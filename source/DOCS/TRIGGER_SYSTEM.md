# Conditional Trigger System

This system allows Triggers to execute different scripts depending on the player's state and interaction type.

## 1. LDtk Configuration

Add the following **Custom Fields** to your `Triggers` entity in LDtk:

*   **Identifier**: `conditionalScripts`
    *   **Type**: `Array<String>`
*   **Identifier**: `type`
    *   **Type**: `String` (Options: `Story`, `Cutscene`, `Search`, `Call`, `Counter`)
*   **Identifier**: `script`
    *   **Type**: `String` (Fallback script name for simple triggers, or single script name)

## 2. Trigger Types and Behaviors

The `type` field determines activation mode and player interaction.

### A. Automatic Triggers (activate on collision, no A press needed)
*   **`Story`**: Fires `dialogUI:addScreen(scriptName)` immediately upon collision.
*   **`Cutscene`**: Disables normal gameplay input and starts a comic-style cutscene.
*   **`Counter`**: Automatically increments `PlayerData.storyCounter` and removes itself (no A press required). Always single-use.

### B. Manual Triggers (require A press)
These show a HUD prompt when the player is inside the trigger area.

*   **`Search`**: Displays an "Investigate" HUD icon. Used for inspecting objects.
*   **`Call`**: Displays a "Radio Ring" HUD icon. Used for radio communications.
*   **`null` (None)**: Shows a standard "Press A" HUD icon.

## 3. Condition Logic (`conditionalScripts`)

Conditions in `conditionalScripts` follow the format `condition:scriptName`.

### A. Boolean Conditions
*   `isTiny:scriptName` — If player is tiny
*   `!isTiny:scriptName` — If player is NOT tiny
*   `items.hasLamp:scriptName` — If player has the lamp

### B. Numerical Comparisons
Supported operators: `>`, `<`, `>=`, `<=`, `==`, `!=`
*   `mapPercent>50:midGameDialogue`
*   `battery<20:lowBatteryWarning`

Evaluation follows **top-to-bottom priority**: the first matching condition is executed.

## 4. Script Resolution

The `script` field (or the script name from `conditionalScripts`) is a **string name** that is used to look up an entry in the global `script` array (loaded from `assets/data/script.lua`):
```lua
-- script.lua structure:
script = {
    { name = "wakeup", dialog = { ... } },
    { name = "firstcall-01", dialog = { ... } },
    -- ...
}
```
The trigger system calls `dialogUI:addScreen(scriptName)`, which searches the global `script` table for an entry where `entry.name == scriptName`.

## 5. Persistence and Single-Use (IMPORTANT)

By default, conditional scripts **DO NOT remove the trigger**. Useful for repeatable hints.

To make a script **remove the trigger** after one use, append `!` to the **script name** (not the condition):

*   `!hasKey:msgLocked` — condition is `!hasKey`, script name is `msgLocked` → **keeps** the trigger (player does NOT have key → repeatable message).
*   `hasKey:openDoor!` — condition is `hasKey`, script name is `openDoor!` → **removes** the trigger (single-use).

**Persistence Defaults:**
*   **Manual Triggers (`Search`, `Call`)**: Persist by default unless `!` is appended to the script name.
*   **`Story` / `Cutscene`**: Usually single-use. Legacy `script` field (non-conditional) removes automatically after activation.
*   **`Counter`**: Always removed after activation.

### How Persistence Works Internally
When a trigger is marked as used, `customFields.usedTrigger = true` is set directly on the trigger's entry in the in-memory `levelsLDTK` table (identified by IID). This change is then persisted via `SaveSystem.save()` (called on room exit), ensuring single-use triggers remain consumed across game restarts.

## 6. Dialog Integration

The trigger system fires `dialogUI:addScreen(scriptName)` to display text.

### Character Portraits (Video Feed)
Each dialog entry can specify a `video` state (e.g., `player`, `playerHappy`).
*   **Tiny State Support**: The `-tiny` suffix is appended in the `videoFeed` component when setting the animation state (`PlayerData.isTiny == true` → state becomes `player-tiny`), **not** in `dialogScreen` itself.

### Localization
All text values in `script.lua` are **localization keys** (e.g., `"firstcall-01"`), not literal strings. They are resolved via `Graphics.getLocalizedText(key)` using the `.strings` files:
*   `source/en.strings` (English)
*   `source/jp.strings` (Japanese)

Example in `en.strings`:
```
"door-locked" = "It's locked from the other side."
```

---

## 🛠️ Love2D Porting Guide

### 1. Trigger Detection
Replace `overlappingSprites()` with `bump.lua` query:
```lua
function Player:checkTriggers()
    local items, len = world:queryRect(self.x, self.y, self.w, self.h)
    for i = 1, len do
        local item = items[i]
        if item.isTrigger and not item.usedTrigger then
            if item.triggerType == "Story" or item.triggerType == "Counter" then
                self:activateTrigger(item)  -- auto-activate
            else
                self.currentTrigger = item  -- show HUD prompt
            end
        end
    end
end
```

### 2. Script Lookup
```lua
-- Build a hash of scripts for O(1) lookup
local scriptByName = {}
for _, entry in ipairs(script) do
    scriptByName[entry.name] = entry
end

function dialogUI:addScreen(scriptName)
    local entry = scriptByName[scriptName]
    if not entry then
        self:removeAll()  -- safe fallback
        return
    end
    PlayerData.isTalking = true
    self:loadScript(entry)
end
```

### 3. usedTrigger Persistence
```lua
-- Mark trigger as used in-memory (will be saved by SaveSystem)
function activateTrigger(trigger)
    if trigger.customFields.usedTrigger then return end
    trigger.customFields.usedTrigger = true
    -- Process script...
end
```

### 4. Localization
Replace `Graphics.getLocalizedText(key)` with your own strings table:
```lua
local strings = require("assets/data/en_strings")
function getLocalizedText(key)
    return strings[key] or key  -- fallback to key if missing
end
```

### 5. Input Gate
Use `PlayerData.isTalking` as a gate — when true, block all player movement and game logic, and route A-button presses to `dialogUI:nextDialog()` instead of game actions.
