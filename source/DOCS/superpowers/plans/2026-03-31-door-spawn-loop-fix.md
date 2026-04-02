# Door Spawn Loop Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replicar el comportamiento de Playdate donde `world:move()` solo se invoca al haber input activo, eliminando el loop de habitaciones y el wall-bouncing al spawn.

**Architecture:** En Playdate, `player:move(direction)` solo se llama desde button handlers — nunca cuando el player está quieto. En LÖVE, `movements.move()` llama `world:move()` cada frame aunque `dx=0,dy=0`. Bump detecta overlaps estáticos y emite colisiones con `overlaps=true`. El fix replica el comportamiento de Playdate con dos guards: (1) skip `world:move()` si no hay movimiento, (2) solo disparar Door si el player recién entró al collider (no si ya estaba superpuesto al inicio del move).

**Tech Stack:** LÖVE 2D, Bump.lua (AABB collision), Lua

**Archivos afectados:**
- `source/entities/player/movements.lua` — agrega early return cuando `dx==0` y `dy==0`
- `source/entities/player/init.lua` — cambia condición de door trigger de `self.manualMovement` a `not col.overlaps`

---

## Contexto técnico para el agente

### Por qué `dx=0, dy=0` causa problemas

En `movements.move()` (movements.lua:41-73), se llama `world:move(player, currentX, currentY, filter)` incluso sin movimiento. En `bump.lua:149-174`:

```lua
if rect_containsPoint(x,y,w,h, 0,0) then -- item was intersecting other
    overlaps = true
    ...
    if dx == 0 and dy == 0 then
        -- intersecting and not moving - use minimum displacement vector
        local px, py = rect_getNearestCorner(x,y,w,h, 0,0)
        ...
        tx, ty = x1 + px, y1 + py  -- push-out position
    end
```

Bump retorna la colisión aunque no haya movimiento. Para walls ('slide'), esto mueve al player. Para doors ('cross'), esto dispara `handleDoorCollision`.

### Por qué `not col.overlaps` es la condición correcta para doors

`col.overlaps = true` significa que el player ya estaba superpuesto al inicio del move. Esto ocurre cuando el player spawna dentro del área del door (y=196 con door en y=232-240, collision box del player en y=220-244 → overlap de 12px).

`col.overlaps = false` significa que el player entró al door durante este frame (cruzó desde afuera → adentro). Esta es la única situación donde se debe disparar la transición.

### Spawn coords correctas (Config es source of truth)

```lua
-- Config.Doors.spawnCoords (NO modificar)
top   = {x=196, y=196},  -- player entra desde arriba (sale de top door en room anterior)
down  = {x=196, y=32 },  -- player entra desde abajo
right = {x=32,  y=116},  -- player entra desde la derecha
left  = {x=364, y=116},  -- player entra desde la izquierda
```

y=196 causa que collision box del player (y+24 a y+48 = 220-244) overlappee con:
- Bottom wall tiles (y=224-240) → wall bouncing (nuevo bug)
- Down door entity (y=232-240) → door loop (bug original)

Ambos se resuelven con el early return en movements.move().

---

## Task 1: Guard en movements.move() — skip world:move cuando dx=0 y dy=0

**Files:**
- Modify: `source/entities/player/movements.lua:41-50`

- [ ] **Step 1: Leer el estado actual del archivo**

Leer `source/entities/player/movements.lua` líneas 40-55 para confirmar el texto exacto antes de editar.

- [ ] **Step 2: Agregar early return al inicio de movements.move()**

En `source/entities/player/movements.lua`, cambiar:

```lua
-- Move player with BUMP collision detection
function movements.move(player, dx, dy, filter)
	-- Clear slideHitWall when player voluntarily moves
	if dx ~= 0 or dy ~= 0 then
		player.slideHitWall = false
	end

	-- BUMP collision - move collision box and get sprite position back
	local newCollisionX = player.x + player.collisionOffsetX + dx
```

Por:

```lua
-- Move player with BUMP collision detection
function movements.move(player, dx, dy, filter)
	-- No movement: skip world:move entirely (matches Playdate's button-driven model
	-- where player:move() is only called on explicit input, never when stationary).
	-- Calling world:move with dx=0,dy=0 causes Bump to detect static overlaps and
	-- emit collisions (bump.lua:149-174), causing wall bouncing and door loops on spawn.
	if dx == 0 and dy == 0 then
		return {}, 0
	end

	-- Clear slideHitWall when player voluntarily moves
	player.slideHitWall = false

	-- BUMP collision - move collision box and get sprite position back
	local newCollisionX = player.x + player.collisionOffsetX + dx
```

- [ ] **Step 3: Verificar manualmente**

Correr el juego con `./run_game.sh` o `love source/`. Ir a Room 2. Confirmar que el player NO rebota contra las paredes al spawn. El player debe aparecer quieto cerca del bottom de la pantalla (cerca del down door).

---

## Task 2: Fix condición de door trigger — usar `not col.overlaps`

**Files:**
- Modify: `source/entities/player/init.lua:197-201`

**Contexto:** Mi cambio anterior usó `self.manualMovement` como guard, que es equivalente a `dx ~= 0 or dy ~= 0`. Esto es redundante con el Task 1 (si dx=0,dy=0, ya no llegamos aquí). Pero necesitamos un guard más preciso: `not col.overlaps`, que previene disparar el door cuando el player ya estaba superpuesto al inicio del move (spawn case). `col.overlaps` viene del objeto retornado por Bump — es `true` cuando los rects ya se solapaban antes del move.

- [ ] **Step 1: Leer el estado actual del archivo**

Leer `source/entities/player/init.lua` líneas 195-205 para confirmar el texto exacto. El archivo fue modificado previamente y tiene `self.manualMovement` como guard.

- [ ] **Step 2: Cambiar la condición del door trigger**

En `source/entities/player/init.lua`, cambiar:

```lua
				-- Specialized Door collision (only when actively moving, like Playdate's button-driven movement)
				if other.class and other.class.name == "Door" and self.manualMovement then
					local DoorHandler = require 'DoorHandler'
					DoorHandler.handleDoorCollision(other, self)
				end
```

Por:

```lua
				-- Specialized Door collision: only fire when player newly enters the door
				-- (col.overlaps = false means player crossed from outside to inside this frame).
				-- col.overlaps = true means player was already inside the door's rect at move
				-- start (spawn case) — don't fire to avoid immediate room loop.
				if other.class and other.class.name == "Door" and not col.overlaps then
					local DoorHandler = require 'DoorHandler'
					DoorHandler.handleDoorCollision(other, self)
				end
```

- [ ] **Step 3: Verificar transición Room 7 → Room 2**

Correr el juego. Desde Room 7, entrar por la Top door hacia Room 2. Confirmar:
- El player aparece en Room 2 sin loop
- El player NO rebota contra paredes
- El player puede moverse libremente en Room 2
- La Down door de Room 2 funciona normalmente al caminar hacia ella

- [ ] **Step 4: Verificar otras transiciones**

Probar transiciones Left/Right y Down/Top para confirmar que las doors siguen funcionando normalmente al caminar hacia ellas (caso `col.overlaps = false`).

---

## Notas de diagnóstico adicionales

### Caso `left` spawn — posible bug latente

`spawnCoords.left.x = 364` — collision box del player: x+8=372 a x+38=402. Right door en rooms estándar: LDtk x=396, width=8 → door.x=392. Overlap de 10px (402>392). Con el fix del Task 1 esto no causa problemas inmediatos (no hay Bump call en dx=0,dy=0) y con `not col.overlaps` tampoco dispara el door. Sin embargo, si el player se mueve a la derecha (hacia el door) en el primer frame, col.overlaps sería true y no dispararía. El player podría "estar dentro" del door sin transicionarse. Reportar al usuario si se observa este comportamiento.

### Archivos NO modificar

- `source/assets/data/Config.lua` — spawn coords son correctas (source of truth)
- `source/DoorHandler.lua` — lógica correcta
- `source/entities/Door.lua` — lógica correcta
- `source/libraries/bump.lua` — no tocar
