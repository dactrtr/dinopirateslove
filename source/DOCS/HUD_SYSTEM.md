# HUD System Documentation

The HUD (Heads-Up Display) provides real-time information about the player's status, including battery life, health, and sanity. It is anchored to the player and drawn on top of the game world.

> [!IMPORTANT]
> **The entire HUD is invisible until `PlayerData.items.hasDWatch == true`.**
> When `hasDWatch` is `false`, the main sprite, battery indicator, and health indicator are all hidden via `setVisible(false)`. The HUD only becomes active once the player collects the DWatch item. This is the primary visibility gate — check `hasDWatch` before rendering any HUD component in a port.

---

## 🖥️ Main Component: `playerHud`
Path: `entities/UI/playerHud.lua`

The `playerHud` is a `NobleSprite` that follows the player and coordinates several sub-indicators.

- **Positioning**: Moves to the player position each frame with a Y offset:
    - Normal mode: `player.y - 36`
    - Tiny mode (`PlayerData.isTiny == true`): `player.y - 22`
- **Sanity States**: The HUD background image changes based on `PlayerData.sanity` using named animation states:

| Animation State | Condition |
|---|---|
| `sanity100` | `sanity > 80` |
| `sanity80` | `sanity > 60` |
| `sanity60` | `sanity > 40` |
| `sanity40` | `sanity > 20` |
| `sanity20` | `sanity > 0` |
| `sanity0` | `sanity == 0` |

The animation states are set via `self.animation:setState('sanity100')` etc. — they are **named strings**, not frame indices.

---

## ❤️ Health Representation: `HealthIndicator`
Path: `entities/UI/healthIndicator.lua`

The Health Indicator represents the player's `healthPoints` (default 10) using 5 hearts in the HUD.

- **Logic**: Each heart represents 2 health points. A full heart is filled with two black squares.
- **Coordinates**: The squares are drawn at specific pixel offsets to align with the `UIHud` image:
    - `xPositions = {4, 5, 10, 11, 16, 17, 22, 23, 28, 29}`
    - `yPos = 8`
- **Update**: Redraws whenever `PlayerData.healthPoints` changes.

---

## 🔋 Battery Indicator: `Battery`
Path: `entities/UI/battery.lua`

The Battery Indicator shows the charge level in the canister.

- **Visibility**: Only visible if `hasDWatch == true` (controlled by `playerHud:update()`).
- **Logic**: Draws a black bar where the width is calculated as `(battery * 27) / 100`.
- **Position**: Offset slightly from the main HUD `(tx, ty - 3)`.

---

## 🗝️ Key Indicator: `keyHud` (Legacy)
Path: `entities/UI/keyHud.lua`

> [!WARNING]
> **Legacy component.** `keyHud` uses `PlayerData.hasKey` (a flat boolean) to show/hide a key icon. However, the actual key system uses `PlayerData.keys[keyNum]` (an indexed table where each key slot can be `true`/`false`). When porting, use the `PlayerData.keys` table — do not rely on `PlayerData.hasKey`.

```lua
-- Legacy keyHud logic (uses flat boolean — deprecated)
function keyHud:update()
    if PlayerData.hasKey == false then
        self:setImage(nil)
    else
        self:setImage(keyIndicator)
    end
end

-- Correct real key system:
-- PlayerData.keys[1] = true  (player has key #1)
-- PlayerData.keys[2] = false (player does not have key #2)
```

---

## 🛠️ Z-Index Management
The HUD and its children use a layered Z-Index to ensure correct rendering order:
- `ZIndex.hud` (2000): Main HUD background.
- `ZIndex.hud + 1`: Battery Indicator.
- `ZIndex.hud + 2`: Health Indicator.

> [!TIP]
> All indicators read directly from the global `PlayerData` (or `_G.PlayerData`) for synchronization.

---

## 🎒 In-Game Menu Overlay
Path: `entities/UI/inGameMenu.lua`

The in-game menu is a separate UI component that overlays the screen to display equipment (Lamp, Boots, Plungerang), a map, and collected crew member hats.
For deep details on how the menu operates and examples for implementing it in Love2D, refer to the [In-Game Menu Documentation](INGAME_MENU.md).

---

## 🛠️ Love2D Porting Guide

### 1. hasDWatch Gate
The most critical difference: **check `PlayerData.items.hasDWatch` before drawing any HUD element**. If false, skip all HUD rendering.

```lua
function HUD:draw()
    if not PlayerData.items.hasDWatch then return end
    -- Draw battery, health, sanity...
end
```

### 2. Sanity Animation States
Use `anim8` or a state machine to map sanity value to the correct frame range. The states map to these frame ranges in the spritesheet (from `playerHud.lua`):

| State | Frames |
|---|---|
| `sanity100` | 1–1 |
| `sanity80` | 3–4 |
| `sanity60` | 5–6 |
| `sanity40` | 7–9 |
| `sanity20` | 10–11 |
| `sanity0` | 12–13 |

```lua
function HUD:getSanityState(sanity)
    if sanity > 80 then return "sanity100"
    elseif sanity > 60 then return "sanity80"
    elseif sanity > 40 then return "sanity60"
    elseif sanity > 20 then return "sanity40"
    elseif sanity > 0  then return "sanity20"
    else return "sanity0"
    end
end
```

### 3. Y Offset (Tiny Mode)
Track the player's `isTiny` state and switch the Y offset:
```lua
local yOffset = PlayerData.isTiny and -22 or -36
self.hudY = player.y + yOffset
```

### 4. Sub-Sprite Tracking
Playdate's sprite system automatically manages child sprites. In Love2D, you must manually track and update `Battery` and `HealthIndicator` positions each frame alongside `playerHud`.

### 5. Key System (Legacy vs. Real)
Do **not** port `keyHud`'s `PlayerData.hasKey` logic. Port to `PlayerData.keys[keyNum]`:
```lua
-- Love2D: check if player has a specific key
function hasKey(keyNum)
    return PlayerData.keys and PlayerData.keys[keyNum] == true
end
```
