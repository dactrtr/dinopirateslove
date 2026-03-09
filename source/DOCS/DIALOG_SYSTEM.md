# Dialog & Script System Documentation

This document explains how the dialog engine works, how scripts are structured, and how localized text and media are displayed.

---

## 📜 Script Data Structure
Dialogs are defined in `source/assets/data/script.lua`. Each script is a table with a unique `name` and a list of `dialog` entries.

### Script Entry Example
```lua
{
    name = "wakeup",
    dialog = {
        { video = 'playerSleepy', text = "wakeup-01" },
        { video = 'playerWorry',  text = "wakeup-02" },
        { video = 'playerSurprise', text = "wakeup-03" }
    }
}
```

- **`video`**: Refers to an animation state name in the `videoFeed` component.
- **`text`**: A **localization key** (e.g., `"wakeup-01"`), **not a literal string**. Resolved via `Graphics.getLocalizedText(key)` against `en.strings` / `jp.strings`.
- **`screen`** (Optional): A `Graphics.image` object to show as a main visual (e.g., cutscene stills).

> [!IMPORTANT]
> All `text` values are localization keys. The system never embeds raw dialog text in `script.lua`. Ensure every key has a matching entry in the `.strings` files.

---

## 📺 UI Components

The system consists of three main classes in `entities/UI/dialog/`:

### 1. `dialogScreen`
The main controller. It manages:
- **`addScreen(scriptName)`**: Searches the global `script` table for an entry with `name == scriptName`. Sets `PlayerData.isTalking = true` and initiates the dialog sequence. If the script name is not found, calls `self:removeAll()` immediately (safe fallback — no nil-index errors).
- **`nextDialog()`**: Advances to the next line. Updates text and `videoFeed` state.
- **`removeAll()`**: Closes the dialog, restores `PlayerData.isTalking = false`, and returns game control.

### 2. `videoFeed`
Displays an animated portrait in the dialog box.
- Supported states: `player`, `playerWorry`, `playerSurprise`, `playerHappy`, `playerAngry`, `playerSleepy`, `radioHand`, `radioRing`, `notesHand`, `tiny`.
- **Dynamic "Tiny" States**: The `-tiny` suffix is appended **in `videoFeed`** when setting the animation state — not in `dialogScreen`. If `PlayerData.isTiny == true`, the requested state (e.g., `"radioHand"`) becomes `"radioHand-tiny"` when `setState` is called.

### 3. `imageScreen`
A helper sprite to display static images (from the script's `screen` field) above the dialog box.

---

## 🕹️ Interaction and Triggers

### Manual Interaction (HUD Feedback)
When the player is inside a manual trigger (`Search` or `Call`), a HUD icon appears:
*   **Investigate Icon**: `Search` type triggers.
*   **Radio Ring Icon**: `Call` type triggers.
*   **Press A Icon**: Default triggers (no type).

Pressing **A** inside these areas calls `dialogUI:addScreen(scriptName)`.

### Automatic Interaction
Triggers of type `Story` or `Cutscene` activate `dialogUI:addScreen` immediately upon collision.

### Navigating Dialogs
While `PlayerData.isTalking == true`:
- Pressing **A** calls `dialogUI:nextDialog()`. This is bound to `AButtonDown` in `MazeScene.lua`.
- Movement and game logic (enemies, etc.) are paused.
- Once the last line is reached, UI closes and `isTalking` is set to `false`.

> [!WARNING]
> **Double-fire Risk**: The A button serves dual purposes — **hold** opens the equipment menu (`AButtonHeld`), **press** advances dialogs (`AButtonDown`). In Love2D ports, both actions need distinct input states. Failing to separate them causes the menu to open while a dialog is being navigated, or dialogs to advance when the menu is being opened.

### Safe Fallbacks
- Missing script name → `removeAll()` fires safely (no crash).
- Tiny mode CrewMember interaction: looks for `<crewId>_tiny` script, falls back to `default_tiny`.

---

## 🌍 Localization
- Text retrieved via `Graphics.getLocalizedText(key, lang)`.
- All keys in `script.lua` must have entries in `source/en.strings` and other language files.

```
-- en.strings format:
"wakeup-01" = "Wha... where am I?"
"nokeys" = "I don't have the key to enter"
```

---

## 🛠️ Love2D Porting Guide

### 1. Script Lookup
```lua
-- Build a lookup hash at load time
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
    self.currentScript = entry
    self.currentLine = 1
    self:showLine(self.currentLine)
end
```

### 2. Localization
```lua
-- Load strings file (simple key=value format)
local strings = {}
for line in love.filesystem.lines("assets/data/en.strings") do
    local key, value = line:match('"(.-)"%s*=%s*"(.-)"')
    if key then strings[key] = value end
end

function getLocalizedText(key)
    return strings[key] or key  -- fallback to key if missing
end
```

### 3. videoFeed with anim8
```lua
-- In videoFeed equivalent:
function VideoFeed:setState(stateName)
    local resolvedState = stateName
    if PlayerData.isTiny then
        resolvedState = stateName .. "-tiny"
    end
    -- Set anim8 animation to resolvedState
    self.currentAnim = self.animations[resolvedState] or self.animations[stateName]
end
```

### 4. Input Gate (isTalking)
```lua
function love.keypressed(key)
    if PlayerData.isTalking then
        if key == "return" or key == "space" then
            dialogUI:nextDialog()
        end
        return  -- block all other input while talking
    end
    -- Normal game input...
end
```

### 5. A Button Dual-Use (Hold vs. Press)
```lua
-- Track hold time for menu:
function love.update(dt)
    if love.keyboard.isDown("return") and not PlayerData.isTalking then
        holdTimer = (holdTimer or 0) + dt
        if holdTimer >= 1.0 then
            inGameMenu:open()
            holdTimer = 0
        end
    elseif not love.keyboard.isDown("return") then
        holdTimer = 0
    end
end

-- A press for dialog (only if not a hold):
function love.keypressed(key)
    if key == "return" then
        if PlayerData.isTalking then
            dialogUI:nextDialog()
            -- Note: the hold timer above won't fire because
            -- isTalking blocks the menu open path
        end
    end
end
```
