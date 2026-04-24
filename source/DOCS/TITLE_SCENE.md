# TitleScene

**File**: `scenes/TitleScene.lua`  
**UI sprites**: `entities/ui/menuTitle.lua`, `entities/UI/titleBackground.lua`

The first scene loaded by `Noble.new(TitleScene)` in `main.lua`. Acts as main menu. Has two distinct modes controlled by the global `debug` flag.

---

## Local State

| Variable | Type | Purpose |
|---|---|---|
| `menuItems` | table | List of menu entries (sprite, states, action) |
| `selectedIndex` | number | Currently highlighted menu item |
| `crankTick` | number | Accumulated crank delta for menu navigation |
| `background` | TitleBackground | Full-screen animated background sprite |
| `isDebugMenu` | bool | Snapshot of `debug` taken on `enter()` |
| `versionSprite` | sprite | Version string rendered top-right |

---

## Lifecycle

### `init()`
- Calls `SaveSystem.createOriginalBackup()` — deep-copies `levelsLDTK` so the game can reset without re-reading files. Only meaningful the first time; subsequent calls are no-ops inside SaveSystem.
- Legacy: writes `playerOriginal` datastore if `levelOriginal.json` doesn't exist (can be removed).

### `enter()`
Rebuilds the entire menu from scratch every time the scene is entered.

1. Sets `PlayerData.isGaming = false`.
2. Renders the **version sprite** (`"* Demo X.X.X *"`) top-right corner at zIndex 200 using an offscreen image drawn with `kDrawModeFillBlack`.
3. Checks `debug` global → sets `isDebugMenu`.
4. Builds menu items (see modes below).
5. Calls `updateMenuSelection()` to apply the initial visual state.

### `exit()`
Removes all `MenuTitle` sprites, the `TitleBackground`, and the version sprite. Clears `menuItems`.

### `update()`
In debug mode only: draws the text-based menu overlay each frame.

---

## Normal Mode (default)

Shown when `debug == false`.

### Background

`TitleBackground` is a full-screen (400×240) `NobleSprite` at position (200,120), zIndex 1. Its spritesheet has one frame per menu state:

| State | Frame |
|---|---|
| `continue` | 1 |
| `deleteGame` | 3 |
| `newGame` | 6 |
| `achievements` | 8 |

Background frame changes via `background:changeState(menuItems[selectedIndex].backgroundState)` whenever selection changes.

### Menu Items

Built at `enter()`. Layout anchor: `startX = 88`, `startY = 120`, `spacing = 20` (px between items).

| Item | Shown when | Action |
|---|---|---|
| **Continue** | `gameState.json` exists | `SaveSystem.load()` → `RoomTranslate(savedLevel)` → `Noble.transition` (Spotlight, 1 s, from player spawn position) |
| **Delete Game** | `gameState.json` exists | `SaveSystem.delete()` → `Utilities.clearAllAchievements()` → restart TitleScene |
| **New Game** | always | `SaveSystem.reset()` → `Noble.transition(Floor407)` (Spotlight, 1 s) |
| **Achievements** | always | `achievements.viewer.launch()` |
| **Credits** | always | `Noble.transition(CreditsScene, 0.3, MetroNexus)` |

Each item holds references to its `MenuTitle` sprite and three animation state names: `defaultState`, `selectedState`, `backgroundState`.

### MenuTitle sprite

`entities/ui/menuTitle.lua` — `NobleSprite`, spritesheet `assets/images/screens/menuTitle`, size 180×56, collision group 3.

Animation frames (each option has a `def*` / `sel*` pair):

| State | Frame |
|---|---|
| defContinue | 1 | selContinue | 2 |
| defNewGame | 3 | selNewGame | 4 |
| defDeleteGame | 5 | selDeleteGame | 6 |
| defAchievements | 7 | selAchievements | 8 |
| defCredits | 9 | selCredits | 10 |
| defPlayground | 11 | selPlayground | 12 |

`updateMenuSelection()` sets the selected item to its `sel*` state and all others to their `def*` state, then syncs the background frame.

---

## Debug Mode

Shown when `debug == true` (toggled via system menu → "debug" or cheat code `up up up down`).

No `TitleBackground` or `MenuTitle` sprites are created. The menu is rendered as plain text in `update()`.

| Item | Action |
|---|---|
| **Playground** | Sets `PlayerData.playerSpawn` to (200, 200) → `Noble.transition(Floor409)` |
| **Cockpit** | `Noble.transition(CockpitScene)` |

Both transitions use `MetroNexus` at 0.3 s.

---

## Input

| Input | Effect |
|---|---|
| D-pad Up | Select previous item (wraps) |
| D-pad Down | Select next item (wraps) |
| Crank | Accumulates into `crankTick`; fires prev/next when `±Config.Input.crankMenuThreshold` is crossed |
| A button | Executes the selected item's `action` |

---

## Continue flow detail

```
SaveSystem.load()
  └─ returns (success, savedLevel)  -- savedLevel is a RoomID integer
RoomTranslate(savedLevel)
  └─ returns FloorXXX scene class
Noble.transition(nextScene, 1, Spotlight, {
  x=200, y=120,            -- spotlight center (screen center)
  xExit=playerSpawn.x,     -- spotlight exit point (player's last position)
  yExit=playerSpawn.y,
  holdTime=0.25,
  ease=Ease.outInQuad
})
```

If `RoomTranslate` returns nil, falls back to `Floor120`.
