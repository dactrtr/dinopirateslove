# CrewMember and Collision Screen Documentation

This document explains how the `CrewMember` entity works and how to show custom screens within the `collisions.lua` system.

---

## 🏴‍☠️ CrewMember Logic

The `CrewMember` is a specialized enemy entity with complex behavior for escaping the player and hiding when trapped. The implementation spans ~492 lines in `entities/enemies/crewmember.lua`.

### 1. Movement & AI

- **Escape Mode**: In its `update` loop, if not hiding or blinded, the `CrewMember` calculates a path away from the player.
- **Movement Budget System** (two distinct functions):
    - **`addMovementTokens(amount)`** (per-entity method, inherited from `Enemy`): Adds `amount × 30` frames of movement budget. 1 token ≈ 1 second of movement at 30fps.
    - **`addMovementFrames(frames)`** (per-entity method, inherited from `Enemy`): Adds raw frames directly (capped at 90 frames to prevent accumulation).
    - **`Player:distributeMovementFrames(frames)`**: Called by the player after each step — distributes raw frames to **all** `Enemy`/`CrewMember` sprites (3 frames per player move).
    - **`Player:distributeMovementTokens(amount)`**: Called on B press — distributes tokens to **all** `Enemy`/`CrewMember` sprites (5 tokens = 150 frames, on B press in `MazeScene.lua`).
    - The `update` loop only processes AI if `movementFrames > 0`.

> [!NOTE]
> `addMovementFrames` and `addMovementTokens` are per-entity methods (add budget to one entity). `distributeMovementFrames` and `distributeMovementTokens` are Player methods (broadcast to all entities).

### 2. Collision & Bouncing

The `CrewMember` uses the dedicated `CollideGroups.crewMember` group:
- **Walls (`Box`)**: `'slide'`
- **Enemies (`Enemy`)**: `'slide'` — blocks movement and triggers bounce logic.
- **Physical Props**: `'slide'` (chairs, tables, etc.)
- **Minifier**: `'overlap'` — passes through freely.
- **Items & Triggers**: `'overlap'`

**Bounce Mechanic**: If blocked by a physical obstacle, `recentBounceCount` increments. The entity enters a "bounce" state for 20 frames, choosing a perpendicular direction.

### 3. Hiding State

If `CrewMember` bounces `bouncesRequiredToHide` (3) times quickly:
- **Invisibility**: Sprite state set to `'hide'`.
- **Non-collidable**: `setCollideRect(0, 0, 0, 0)`, collision groups cleared.
- **Exit Conditions**:
    1. Player must be outside `hidingVisionRange` (80 pixels).
    2. `hidingMovementTokensRequired` (3) tokens must be accumulated.

### 4. Special Interactions

- **Blinding (`blind(frames)`)**: Stops the entity for a set number of frames (timed stun).
- **Infinite Stun (`stunInfinite()`)**: **Indefinite immobilization** — the CrewMember is frozen permanently until the game state changes. This is a **precondition for capture**, typically triggered by the Plungerang hitting the CrewMember.

> [!IMPORTANT]
> `stunInfinite()` is not a timed effect. It permanently immobilizes the CrewMember until explicitly released. After `stunInfinite()`, the player can capture them with `other:taken()`.

- **Plungerang**: When the Projectile hits a `crewMember` group entity, it calls `other:stunInfinite()` **and** sets `self.player.hasProjectile = false` (losing the boomerang).
- **Taking (`taken()`)**: Marks the CrewMember as captured in `PlayerData`, updates UI count, removes the sprite.

### 5. Tiny Mode Interactions

If `PlayerData.isTiny == true`:
- **No Escape**: `search()` defaults to `idle` — CrewMember does not run away.
- **Trigger Behavior**: Collision sets `player.currentTrigger = crewMember` (`'overlap'` response).
- **Dialogs**: Player can press A to open dialog using `tinyScript`, falling back to `<crewId>_tiny` or `default_tiny`.

---

## 📺 Custom Screens in Collisions

### 1. The Collision Hook

In `source/entities/player/collisions.lua`, `Player:collisionResponse(other)` handles interactions.

**Note**: Colliding with a `CrewMember` does **not** trigger damage or invincibility.

```lua
elseif other:isa(CrewMember) then
    if PlayerData.isTiny then
        self.currentTrigger = other
        return 'overlap'
    end
    if PlayerData.CrewMemberData.amountTaken == 0 then
        self.dialogUI:addScreen("gotcha", other.sourceFeed)
    end
    other:taken()
```

### 2. How `addScreen` Works

`dialogUI:addScreen(scriptName)`:
- Searches global `script` table for `name == scriptName`.
- Sets `PlayerData.isTalking = true`.
- Displays associated text, video feed, or images.

### 3. Adding Custom Screens

1. **Define the Script** in `assets/data/script.lua`:
    ```lua
    {
        name = "my_custom_screen",
        dialog = {
            { text = "my-localization-key", video = "playerSurprise" }
        }
    }
    ```
    Note: `text` is a localization key, not a literal string.
2. **Call it** in `collisions.lua`:
    ```lua
    self.dialogUI:addScreen("my_custom_screen")
    ```

> [!TIP]
> Use `other.sourceFeed` as a second argument to pass a specific video feed index to the dialog system.

---

## 🛠️ Love2D Porting Guide

### Key Porting Notes for CrewMember (~492 lines)

1. **Movement Token System**: Port both `addMovementFrames` and `addMovementTokens` as separate methods. The cap of 90 frames for raw frames must be preserved.

2. **stunInfinite vs blind**: These are **different mechanisms**:
    - `blind(frames)`: timed — decrement counter each frame until zero.
    - `stunInfinite()`: permanent — set a flag, no timer. Only clearable by explicit reset.

3. **Hiding State**: The collision group clearing (`setCollideRect(0,0,0,0)` and group removal) must be replicated — in bump.lua, `world:remove(self)` and `world:add(self, 0, 0, 0, 0)` or simply skip collision processing when hiding.

4. **Tiny Mode Branch**: Two different collision paths in `Player:collisionResponse` based on `PlayerData.isTiny`. Both must be ported.

5. **playdate.timer for stun**: If `blind()` uses `playdate.timer`, replace with a frame counter:
    ```lua
    function CrewMember:update(dt)
        if self.isBlinded then
            self.blindFrames = self.blindFrames - 1
            if self.blindFrames <= 0 then self.isBlinded = false end
            return
        end
        -- normal AI...
    end
    ```
