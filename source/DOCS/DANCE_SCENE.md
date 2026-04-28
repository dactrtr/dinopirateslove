# DanceScene — Rhythm Combat System

`scenes/DanceScene.lua` and `entities/UI/battle/`

---

## Overview

DanceScene is the rhythm-based combat encounter that triggers when the player collides with a Brocorat and their health drops below the damage threshold. The player must press the correct buttons in sync with scrolling prompts to push a balance bar into the win zone. Winning kills the enemy and returns to the maze; losing goes to TitleScene (Game Over).

---

## Entry Point

In `entities/player/collisions.lua`, when the player overlaps a Brocorat:

1. `PlayerData.lastEnemyTouched` is filled with the enemy's `id`, `type`, `x`, `y`.
2. Damage is applied: `PlayerData.healthPoints -= other.damage`.
3. If `healthPoints < PlayerData.danceThresholdHP` (default `5`): `self:fight()` is called.
4. Otherwise: `startInvincibility(Config.Invincibility.duration)` — no battle triggered.

`Player:fight()` in `state.lua`:
- Increments `PlayerData.amountDances`.
- Calls `Noble.transition(DanceScene)`.

> `amountDances` is incremented again on a win inside `checkDanceResults()` — so it ends up counting **twice** per fight.

---

## Scene Lifecycle

### `init()`
- Sets `display.setRefreshRate(50)`.
- Seeds `math.randomseed` from `playdate.getCurrentTimeMilliseconds()`.
- Initializes battle state:
  - `bpm = 16` (default tempo)
  - `enemyHP = 50` (max distance on balance bar)
  - `evadePower = 30`
  - `lifes = 3`
  - `balancePosition = 0`, `balanceMaxOffset = 50`
  - `numberOfButtons = 4`
  - `correctButtonPresses` — per-button hit counter

### `enter()`
1. Runs `determineDifficultyUpgrade()` → probabilistic roll → sets `enemyType`.
2. Reads `Config.Dance[enemyType]` → configures `bpm` and `numberOfButtons`.
3. Creates `numberOfButtons` `ButtonPress` instances using a `keyProvider` function tied to the enemy's `EnemyPatterns` profile.
4. Spawns all battle UI sprites (see [UI Entities](#ui-entities)).

### `start()`
- Staggers each `ButtonPress` by `300 ms × index` using `movementDelay()`. This prevents all buttons from starting simultaneously.

### `update()`
Main loop logic — see [Hit Detection](#hit-detection-and-balance-bar).

### `exit()`
- Removes all battle sprites and nils references.
- Resets `PlayerData.healthPoints = 2`.
- Calls `SaveSystem.save()`.

---

## Difficulty System

### `determineDifficultyUpgrade()` — Probability Roll

Each encounter computes a weighted upgrade probability from three `PlayerData` values:

| Input | Weight | Config Key | Normalization Max |
|---|---|---|---|
| `sanityCounter` | 0.35 | `weightSanity` | 100 |
| `EnemiesData.powerLevel` | 0.45 | `weightPower` | 20 |
| `calories` | 0.20 | `weightCalories` | 500 |

```
probability = (sanityNorm × 0.35 + powerNorm × 0.45 + caloriesNorm × 0.20) × 100
```

A `math.random(0, 100)` roll is compared against `probability`:
- **Roll ≤ probability** → upgrade succeeds → `determineEnemyType()` picks profile.
- **Roll > probability** → stay at `"basic"` regardless of power level.

### `determineEnemyType()` — Profile Selection

Based on `PlayerData.EnemiesData.powerLevel`:

| Enemy Type | Power Level | BPM | Buttons | Pattern Style |
|---|---|---|---|---|
| `basic` | 1–5 | 16 | 4 | Mostly arrows (80%) |
| `evolve` | 6–12 | 24 | 6 | Mixed (60% arrows, 20% A, 20% B) |
| `badass` | 13–19 | 28 | 8 | Tough (40% arrows, 30% A, 30% B) |
| `boss` | 20 | 32 | 12 | Button spam (20% arrows, 40% A, 40% B) |

### EnemyPatterns

Each profile has a `weights` table and `phaseLength`. `getPatternKey(profile)` does a weighted random draw to return one of: `"leftButton"`, `"upButton"`, `"rightButton"`, `"downButton"`, `"aButton"`, `"bButton"`.

---

## UI Entities

All live in `entities/UI/battle/`. Z-index layering from back to front:

| Z | Entity | Size | Position | Role |
|---|---|---|---|---|
| 1 | `BackgroundDance` | 400×240 | 200,120 | Fullscreen battle background |
| 2 | `EnemyRatDance` | 214×214 | 158,26 | Enemy sprite with attack animations |
| 4 | `ButtonPress` | 32×32 | Scrolling | Moving button prompts |
| 5 | `HitZone` | 10×40 | 40,30 | Left-side hit area |
| 6 | `PlayerDance` | 246×214 | 0,26 | Player sprite with dance animations |
| 9 | `ButtonCover` | 78×58 | 361,32 | Decorative panel over button icons |
| 9 | `WinIndicator` | 39×31 | Right threshold | Enemy-side marker |
| 9 | `LoseIndicator` | 39×31 | Left threshold | Player-side marker |
| 10 | `ResultsScreen` | 400×240 | 200,120 | Win/lose/ready overlay |

### ButtonPress
- Spawned `numberOfButtons` times, each sharing the same `keyProvider` function.
- Starts off-screen right (`startPoint = 400 + bpm`), scrolls left each frame at speed `0.5 × bpm / 3`.
- When it exits left (x ≤ 32): teleports back to `startPoint` and picks a new key from the provider.
- After a hit: shows `"empty"` frame briefly, resets to `startPoint`, picks a new key.
- Each `ButtonPress` has a collision rect (32×32). It collides with other `ButtonPress` sprites as `'freeze'`, and with everything else as `'overlap'`.

### HitZone
- Fixed 10×40 sprite at `(40, 30)`.
- `overlappingSprites()` is called each update frame to detect which `ButtonPress` is in zone.
- Has a looping `checker` animation (frames 1–8).

### ResultsScreen
- Full-screen overlay sprite (ZIndex 10).
- States: `'empty'` (transparent), `'ready'` (pre-battle prompt), `'win'`, `'lose'`.
- Shown at the start in `'ready'` state. Cleared to `'empty'` when battle begins.

---

## Pre-Battle "Ready" Screen

When the scene first enters, `PlayerData.isDancing = false`. The `update()` loop detects this and calls `resultsScreen:loadingScreen()` (shows `'ready'` state), then returns early — no hit detection runs.

The player must press **A** to start:
- `AButtonDown` checks `isDancing == false` → calls `scene:startBattle()`.
- `startBattle()`: sets `resultsScreen` to `'empty'`, sets `PlayerData.isDancing = true`, calls `enemyDance:setIdle()`.

---

## Hit Detection and Balance Bar

Each `update()` frame (when `isDancing == true`):

```
collisions = hitzone:overlappingSprites()
```

### Case 1: Button in zone, no input (`ButtonPressed == nil`)
- `accuracy += 1` (increments while button sits in zone without a press).
- If `accuracy > 5`: `balancePosition -= 0.3` (slow drift toward lose side).
- `enemyDance:changeAnimation(collisions[1].buttonKey)` — enemy reacts to the prompt.

### Case 2: Correct input (`collisions[1].buttonKey == ButtonPressed`)

**A or B button:**
- `enemyDance:attackAnimation(buttonKey)` — enemy attack animation.
- `enemyHP -= 10`.
- `balancePosition += 5`.

**Arrow button:**
- `balancePosition += accuracy` — more points for pressing early.
- `totalAccuracy += accuracy`.
- `evadePower = totalAccuracy`.
- `playerDance:changeAnimation(ButtonPressed)` — player dances.

In both cases: `collisions[1]:hit()` resets the ButtonPress and `incrementCorrectPress()` tallies the hit.

### Case 3: Wrong input
- `balancePosition -= 5`.
- `collisions[1]:hit()` (consumes the prompt anyway).

### Case 4: No button in zone
- `accuracy = 0` (resets streak).

After each collision block, `ButtonPressed` is reset to `nil`.

---

## Balance Bar

The balance bar (`nudgeIndicator` image) is drawn centered at:

```
screenCenterX + balancePosition - barWidth / 2
```

- `screenCenterX = 200`, `barWidth = 8`, `barY = 56`.
- `balancePosition` is clamped to `[-balanceMaxOffset, +balanceMaxOffset]` (±50).
- **Win**: `balancePosition >= balanceMaxOffset` → `resultsScreen:win()`, `isDancing = false`, `condition = "win"`.
- **Lose**: `balancePosition <= -balanceMaxOffset` → `resultsScreen:lose()`, `isDancing = false`, `condition = "lose"`.

`WinIndicator` sits at `screenCenterX + balanceMaxOffset + 2×barWidth` (right edge).  
`LoseIndicator` sits at `screenCenterX - balanceMaxOffset - 2×barWidth` (left edge).

---

## Animations

### PlayerDance (`playerDance-table-246-214.png`)

| Input | Animation State | Frames |
|---|---|---|
| `upButton` | `jump` | 5–9 |
| `downButton` | `crouch` | 11–15 |
| `leftButton` | `left` | 16–20 |
| `rightButton` | `right` | 21–24 |
| A or B | *(no change)* | — |

Arrow inputs only — A/B do not change the player sprite.

### EnemyRatDance (`enemyDance-table-211-214.png`)

`changeAnimation()` — triggered when a button is **in the zone** (prompt visible):

| Button in Zone | Enemy State |
|---|---|
| `downButton` | `upAttack` |
| `upButton` | `downAttack` |
| `leftButton` | `leftAttack` |
| `rightButton` | `rightAttack` |

`attackAnimation()` — triggered on **correct A/B press**:

| Input | Enemy State |
|---|---|
| `aButton` | `aButton` (frames 26–29) |
| `bButton` | `bButton` (frames 22–25) |

Both attack states return to `idle` when done. The `evolving` state (frames 30–33) exists but is not triggered during normal combat.

All four enemy types (`basic`, `evolve`, `badass`, `boss`) share the same animation frame ranges — only BPM and button count differ.

---

## Win / Lose Outcomes

### Win (`checkDanceResults()` with `condition == "win"`)
1. Calls `findAndKillEnemyById(PlayerData.lastEnemyTouched.id)` — marks enemy `dead` in `levelsLDTK`.
2. `PlayerData.healthPoints += PlayerData.healedHP`.
3. Player spawn reset to `playerExit` position.
4. `PlayerData.amountDances += 1` and `PlayerData.calories += 60`.
5. `Noble.transition(RoomTranslate(PlayerData.saveLevel), 0.3, Noble.Transition.Default)` — back to the room.

### Lose (`checkDanceResults()` with `condition == "lose"`)
- `Noble.transition(TitleScene, 0.3, Noble.Transition.MetroNexus)` — Game Over.

`checkDanceResults()` is called from `AButtonDown` (and can be called from any button handler, though currently only A is wired). The `condition` variable is file-scoped so it persists through input events in the same frame.

---

## Input Mapping

| Button | `danceStep()` key |
|---|---|
| A | `"aButton"` |
| B | `"bButton"` |
| D-pad Left | `"leftButton"` |
| D-pad Right | `"rightButton"` |
| D-pad Up | `"upButton"` |
| D-pad Down | `"downButton"` |

`ButtonDown` → `scene:danceStep(key)` sets `self.ButtonPressed`.  
`ButtonUp` → `scene:clearButton()` nils `self.ButtonPressed`.

`AButtonDown` also handles the pre-battle → battle transition and calls `checkDanceResults()` after every press (safe because `condition` is only set on win/lose).

---

## Config Reference

All Dance values are in `Config.Dance` (`assets/data/Config.lua`):

```lua
Config.Dance = {
    basic  = { bpm = 16, buttons = 4  },
    evolve = { bpm = 24, buttons = 6  },
    badass = { bpm = 28, buttons = 8  },
    boss   = { bpm = 32, buttons = 12 },

    sanityMax   = 100,
    powerMax    = 20,
    caloriesMax = 500,

    weightSanity   = 0.35,
    weightPower    = 0.45,
    weightCalories = 0.20,
}
```

---

## Key PlayerData Fields

| Field | Role in DanceScene |
|---|---|
| `isDancing` | `false` = ready screen, `true` = battle active |
| `lastEnemyTouched` | `{id, type, x, y}` — set before fight(), used to kill enemy on win |
| `danceThresholdHP` | HP value below which fight() triggers (default 5) |
| `EnemiesData.powerLevel` | Determines enemy type (1–20) |
| `sanityCounter` | Feeds difficulty roll weight |
| `calories` | Feeds difficulty roll weight |
| `healedHP` | HP recovered on win |
| `amountDances` | Total encounter counter (incremented on enter and on win) |
| `playerExit` | Spawn position restored on win |
| `saveLevel` | Used by `RoomTranslate()` to find the return room |
