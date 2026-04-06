# Conditional Trigger System

This system allows Triggers to execute different scripts depending on the player's state and interaction type.

> **See also:** [CUTSCENE_SYSTEM.md](CUTSCENE_SYSTEM.md) for the full Cutscene trigger
> code path and Panels integration. [PLAYERDATA_REFERENCE.md](PLAYERDATA_REFERENCE.md)
> for `isCutscene` and `isGaming` flag semantics.

> [!NOTE]
> `Trigger` extends `Graphics.sprite` directly (the base Playdate sprite class), **not** `NobleSprite`. Constructor signature: `Trigger(x, y, width, height, script, iid, room, type)`. The trigger positions to `(x - width/2, y - height/2)` since the LDtk `x`/`y` is the center point.

## 1. LDtk Configuration

Add the following **Custom Fields** to your `Triggers` entity in LDtk:

*   **Identifier**: `conditionalScripts`
    *   **Type**: `Array<String>`
*   **Identifier**: `type`
    *   **Type**: `String` (Options: `Story`, `Cutscene`, `Search`, `Call`, `Counter`)
*   **Identifier**: `script`
    *   **Type**: `String` (Used as a fallback or for simple triggers)

### Trigger constructor (Lua)

```lua
-- trigger.lua
-- Note: extends Graphics.sprite (base Playdate sprite), NOT NobleSprite
function Trigger:init(x, y, width, height, script, iid, room, type)
    self.script = script   -- comics key (Cutscene) or dialog script name (Story/Search/Call)
    self.iid    = iid      -- LDtk instance unique ID (used for save/restore matching)
    self.room   = room     -- index into levelsLDTK (NOT the room number)
    self.type   = type     -- "Cutscene"|"Story"|"Search"|"Call"|"Counter"|nil

    -- Position offset: LDtk x/y is center; sprite origin is top-left
    self:moveTo(x - width/2, y - height/2)
    self:setCollideRect(0, 0, width, height)
    self:setZIndex(3)
    self:setGroups(3)
    self:add()
end
```

## 2. Trigger Types and Behaviors

The `type` field determines how the trigger is activated and how the player interacts with it.

### A. Automatic Triggers
*   **`Story`**: Activated automatically upon collision. Calls `dialogUI:addScreen(scriptName, other.sourceFeed)` — note the `sourceFeed` second argument passes the video feed index.
*   **`Cutscene`**: Activated automatically upon collision. Full code path:

    ```lua
    -- player/collisions.lua — what actually happens:
    PlayerData.isGaming = false
    PlayerData.isCutscene = true      -- MazeScene:update() sees this and calls Panels.update()
    other:returnScript()              -- marks usedTrigger=true in levelsLDTK (persisted on save)
    other:remove()                    -- sprite removed; won't collide again
    Utilities.grantAchievementIfNeeded(other.script)
    ```

    **Important:** `collisionResponse` does NOT call `Panels.startCutscene()`. It only
    sets flags. The Panels sequence must be started separately — either extend
    `collisionResponse` to call `Panels.startCutscene(comics[other.script], callback)`,
    or rely on a room-entry cutscene playing automatically. See [CUTSCENE_SYSTEM.md](CUTSCENE_SYSTEM.md) for full details.

    The `script` field on the trigger is a key into the `comics` table registry.
    `returnScript()` returns it, but the return value is **discarded** by `collisionResponse`.
*   **`Counter`**: Activated automatically upon collision. It increments the global `PlayerData.storyCounter` and removes itself immediately.

### B. Manual Triggers (Interactable)
These triggers do not activate automatically. Instead, they show a HUD prompt when the player is inside the trigger area, requiring the player to press **A** to activate.

*   **`Search`**: Displays an "Investigate" HUD icon. Used for inspecting objects in the world.
*   **`Call`**: Displays a "Radio Ring" HUD icon. Used for incoming or outgoing radio communications.
*   **`null` (None)**: If no type is specified, it defaults to showing a standard "Press A" HUD icon.

## 3. Condition Logic (`conditionalScripts`)

Conditions in `conditionalScripts` follow the format `condition:script`.

### A. Boolean Conditions
*   `isTiny:script` (If player is tiny)
*   `!isTiny:script` (If player is NOT tiny)
*   `items.hasLamp:script` (If player has the lamp)

### B. Numerical Comparisons
Supported operators: `>`, `<`, `>=`, `<=`, `==`, `!=`
*   `mapPercent>50:midGameDialogue`
*   `battery<20:lowBatteryWarning`

Evaluating follows a **top-to-bottom** priority. The first condition met will be executed.

## 4. Persistence and Single-Use (IMPORTANT)

By default, conditional scripts **DO NOT remove the trigger**. This is useful for repeatable hints or "locked" messages.

To make a script **remove the trigger** after one use, append `!` to the end of the script name.

*   `!hasKey:msgLocked` -> **Keeps** the trigger (Player can see it multiple times).
*   `hasKey:openDoor!` -> **Removes** the trigger (Occurs only once).

**Persistence Defaults (when using the legacy `script` field, not `conditionalScripts`):**
*   **`Search`**: Persists — it is the **only** type that does NOT consume itself when using the plain `script` fallback.
*   **`Story`, `Cutscene`, `Call`, `Counter`, and untyped**: All removed after first activation when using the plain `script` field.
*   **`Counter`**: Always removed after activation regardless of mode.

## 5. Dialog Integration

The trigger system communicates with `dialogUI:addScreen(scriptName)` to display text.

### Character Portraits (Video Feed)
Each dialog entry can specify a `video` state (e.g., `player`, `playerHappy`). 
*   **Tiny State Support**: If `PlayerData.isTiny` is true, the system automatically appends `-tiny` to the video state (e.g., `player-tiny`) to show the correct miniature portrait.

---

## 🎮 Love2D Porting Notes

### 1. Trigger as bump.lua Sensor
Replace `Graphics.sprite` triggers with bump.lua ghost objects:
```lua
world:add({type="trigger", triggerType="Search", script="myScript", iid=iid},
    x - w/2, y - h/2, w, h)

-- Detect in player collision filter:
if other.type == "trigger" then return "cross" end
```

### 2. Condition Evaluation
`returnScript()` and `conditionalScripts` are pure Lua logic (string parsing + `PlayerData` field checks). Copy the condition evaluator directly — it has no Playdate dependencies.

### 3. Manual Trigger HUD Prompt
In Playdate, `MazeScene` checks `PlayerData.currentTrigger` each frame. In Love2D:
```lua
-- In love.update: track if player overlaps a manual trigger
if overlapsTrigger and not playerData.isTalking then
    currentTrigger = trigger
    showHudIcon(trigger.triggerType)  -- "Search", "Call", etc.
end

-- In love.keypressed:
if key == "return" and currentTrigger then
    dialogUI:addScreen(currentTrigger:returnScript(), currentTrigger.sourceFeed)
end
```

### 4. Cutscene Flag → Panels Equivalent
In Love2D, instead of the `isCutscene` flag + Panels library, trigger your cutscene/comic system directly from the trigger collision:
```lua
if trigger.triggerType == "Cutscene" then
    playerData.isGaming = false
    CutsceneManager:play(trigger:returnScript())
    trigger:remove()
end
```

### Localization
All text keys used in `script.lua` must be defined in the localization files:
*   `source/en.strings` (English)
*   `source/jp.strings` (Japanese)

**Example Entry in `en.strings`**:
`"door-locked" = "It's locked from the other side."`
