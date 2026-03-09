# 🪠 Plungerang System

The **Plungerang** is a versatile skill in *Dinopirates*. It functions as a boomerang-style projectile that allows for long-range enemy stunning, prop interaction, and crew member immobilization.

---

## 🏗️ Core Mechanics

The system is split between two main components:
1.  **Skill Logic**: Located in `entities/player/plunge.lua`. Handles input validation and state management.
2.  **Projectile Entity**: Located in `entities/player/projectile.lua`. Handles physical movement, collisions, and lifecycle.

### 1. Activation (`Player:plunge`)

The skill is triggered when the player uses the **Action** button while the Plunger is equipped.

**Requirements** (all must be true):
- `PlayerData.activeItem == 3` (Plunger must be equipped in the active slot).
- `PlayerData.items.hasPlunger == true` (player must own the item).
- `PlayerData.skills.canPlungerang == true` (player must have the skill unlocked).
- Player is **not** in `isTiny` state.
- No projectile currently in flight (`isPlunging` guard).
- Player has a directional heading (not in `idle` state).
- `self.hasProjectile == true` (the physical boomerang must still exist — not lost to a CrewMember).

### 2. Physical Lifecycle

When launched, a `Projectile` sprite is created and follows three phases:
- **Phase A: Launch**: Moves in the player's initial firing direction (Left, Right, Up, Down).
- **Phase B: Maximum Distance**: Travels up to `maxDistance` (default: 100 pixels) before auto-entering the Return phase.
- **Phase C: Return**: Homes toward the player's **current** position.

### 3. Movement Locking

While the projectile is in flight:
- `self.isPlunging = true` is set.
- The player is set to an `idle` animation state.
- **Movement is always completely locked** — standard movement and other skills are disabled until the projectile is caught or lost. There are no conditions under which movement remains unlocked during flight.

---

## 🎯 Interactions & Collisions

| Target | Result | Effect |
| :--- | :--- | :--- |
| **Enemy** | Hit & Return | Calls `blind(60)` — stuns the enemy for 60 frames. Returns immediately. |
| **Props / Walls** | Hit & Return | Bounces off collision box and begins the return phase. |
| **CrewMember** | **Projectile Lost** | Calls `stunInfinite()` on the CrewMember (indefinite immobilization, precondition for capture). Sets `self.hasProjectile = false`. Projectile is gone until recovered. |
| **Player (Catch)** | Skill Success | Resets `isPlunging = false` and restores movement. |

> [!WARNING]
> **Losing the Plungerang**: Hitting a `CrewMember` also calls `stunInfinite()` on them (permanent immobilization), but you lose the projectile. You must find it again in the world to restore the skill.

> [!NOTE]
> The `isActive` system continues to run during flight (enemies still consume their movement budget), creating real tactical risk when missing a target.

---

## 🛠️ Love2D Porting Guide

Implementing the Plungerang in Love2D requires migrating from `NobleSprite` to a standard class with `bump.lua`.

### 1. Projectile Class Structure
```lua
local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(player, direction)
    local self = setmetatable({}, Projectile)
    self.player = player
    self.speed = 480    -- Pixels per second (8 * 60fps)
    self.returning = false
    self.maxDistance = 100
    self.traveledDistance = 0
    self.x, self.y = player.x, player.y
    self.direction = direction
    world:add(self, self.x, self.y, 16, 16)
    return self
end

function Projectile:update(dt)
    if self.returning then
        local dx, dy = self.player.x - self.x, self.player.y - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < 10 then
            self:onCaught()
            return
        end
        local vx, vy = (dx/dist) * self.speed, (dy/dist) * self.speed
        self:move(vx * dt, vy * dt)
    else
        -- Linear movement
        local moveX, moveY = 0, 0
        if     self.direction == "left"  then moveX = -self.speed * dt
        elseif self.direction == "right" then moveX =  self.speed * dt
        elseif self.direction == "up"    then moveY = -self.speed * dt
        elseif self.direction == "down"  then moveY =  self.speed * dt
        end
        self:move(moveX, moveY)
        self.traveledDistance = self.traveledDistance + math.abs(moveX) + math.abs(moveY)
        if self.traveledDistance >= self.maxDistance then
            self.returning = true
        end
    end
end
```

### 2. Collision Filter (`bump.lua`)
```lua
local function plungerFilter(item, other)
    if other.isEnemy or other.isWall then return 'touch' end
    if other.isCrewMember then return 'touch' end
    if other.isPlayer and item.returning then return 'touch' end
    return 'cross'
end
```

### 3. State Syncing
```lua
function Player:update(dt)
    if self.isPlunging then
        -- Movement is ALWAYS blocked — no exceptions
        return
    end
    -- Normal input processing...
end
```

### 4. Requirements Check
```lua
function Player:canPlunge()
    return PlayerData.activeItem == 3
        and PlayerData.items.hasPlunger
        and PlayerData.skills.canPlungerang
        and not PlayerData.isTiny
        and not self.isPlunging
        and self.hasProjectile
        and PlayerData.direction ~= 'idle'
end
```

### 5. CrewMember Hit (Special Case)
```lua
-- When projectile hits a CrewMember:
function Projectile:onHitCrewMember(crewMember)
    crewMember:stunInfinite()     -- permanent immobilization
    self.player.hasProjectile = false  -- lose the boomerang
    self:destroy()
end
```
