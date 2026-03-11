# Props & Items Documentation

This document details the environment objects (Props) and collectibles (Items) that populate the game world.

---

## 📦 Items (Pickups)

Items are specialized sprites that grant the player new abilities or resources upon contact.

### 1. Item Types & Rendering
Items are implemented in `entities/items/Items.lua`.
- **Tileset**: `assets/images/items/items-key-table-32-32.png`
- **Size & Colliders**: Every item is `32×32` pixels, on the `ZIndex.items` layer.
- **Animation**: All item animations operate at an 8-frame duration.
  - **`boots`**: (Frames 1–3) Prevents falling into holes if battery is available.
  - **`plunger`**: (Frames 4–6) Prevents sliding on slime tiles (89–97).
  - **`lamp`**: (Frames 7–9) Enables visibility in dark rooms; triggers sanity regen logic.
  - **`notes`**: (Frames 10–12) Story-relevant item.
  - **`keycard`**: (Frames 13–15) Grants access to doors with matching `keyNumber`.
  - **`itemgift`**: (Frames 16–18) Generic delivery item — grants items/skills via `grants` field.

### 2. Sprite Sheet — Coordenadas Detalladas

Hoja: `assets/images/items/items-key-table-32-32.png`
Tamaño por frame: **32×32 px**. Todos los ítems tienen **3 frames de animación** con duración de 8 frames cada uno.

| Tipo de ítem | Frames en hoja | Columnas (32 px c/u) | Descripción visual |
|---|---|---|---|
| `boots` | 1 – 3 | cols 1-3, fila 1 | Botas de plataforma, animación de brillo |
| `plunger` | 4 – 6 | cols 4-6, fila 1 | Sopapa / ventosa, parpadeo |
| `lamp` | 7 – 9 | cols 7-9, fila 1 | Linterna, pulso de luz |
| `notes` | 10 – 12 | cols 10-12, fila 1 | Papeles/notas, ondeo |
| `keycard` | 13 – 15 | cols 13-15, fila 1 | Tarjeta llave, destellos |
| `itemgift` | 16 – 18 | cols 16-18, fila 1 | Caja regalo genérica |

> Todos los ítems están en una sola fila horizontal. La numeración de frames empieza en 1 (convención Noble Engine / Playdate imageTable).

**Hoja de íconos del menú** (`assets/images/ui/menu/menuitems-table-32-32.png`):

| Frame | Estado | Ítem representado |
|---|---|---|
| 1 | Sin seleccionar | Plunger (sopapa) |
| 2 | Seleccionado | Plunger |
| 3 | Sin seleccionar | Boot (botas) |
| 4 | Seleccionado | Boot |
| 5 | Sin seleccionar | Lamp (linterna) |
| 6 | Seleccionado | Lamp |

---

### 3. Posicionamiento y Sistema de Grants (LDtk)

```lua
Items(x, y, type, keyNumber, cf.grants)
```

#### ¿Qué es `grants`?

`grants` es un campo personalizado de LDtk que define qué entrada de `PlayerData` se modifica al recoger el ítem. Es la forma extensible de otorgar habilidades o ítems sin hardcodear una función `grab*()` específica.

**Formato:**
```
"clave1:valor1,clave2:valor2,..."
```

**Ejemplos reales del juego:**
```lua
grants = "canDance:true"          -- notes en Room 1: desbloquea la habilidad de bailar
grants = "hasDWatch:true"         -- itemgift en Room 14: otorga el reloj digital
grants = "canFlash:true"          -- otorga habilidad de luz burst
grants = "hasBoots:true,canDash:true"   -- otorga botas Y habilidad de dash juntas
```

#### Cómo se procesan los grants (`processGrants`)

Implementado en `entities/player/items.lua`:

```lua
function Player:processGrants(grants, targetTable)
  if not grants or grants == "" then return end
  for pair in string.gmatch(grants, "([^,]+)") do
    local key, value = string.match(pair, "([^:]+):([^:]+)")
    if key and value then
      key   = key:gsub("%s+", "")       -- elimina espacios
      value = value:gsub("%s+", "")
      -- Conversión automática de tipos
      local val = value
      if     value == "true"  then val = true
      elseif value == "false" then val = false
      elseif tonumber(value)  then val = tonumber(value)
      end
      targetTable[key] = val
      printDebug("🎁 Granted:", key, "=", val)
    end
  end
end
```

**Conversión de tipos automática:**
| Valor en string | Resultado en Lua |
|---|---|
| `"true"` | `true` (boolean) |
| `"false"` | `false` (boolean) |
| `"5"` | `5` (number) |
| Cualquier otro | string sin cambios |

#### ¿A qué tabla de PlayerData va cada tipo?

| Tipo de ítem | Función llamada | Tabla destino |
|---|---|---|
| `notes` | `Player:grabNotes(grants)` | `PlayerData.skills` |
| `itemgift` | `Player:grabItemGift(grants)` | `PlayerData.items` |

> **Regla:** `notes` → habilidades/skills. `itemgift` → ítems del inventario.

#### Claves válidas para `PlayerData.items` (via itemgift)

| Clave | Tipo | Efecto |
|---|---|---|
| `hasLamp` | bool | Posee la linterna |
| `hasRadio` | bool | Posee la radio |
| `hasDWatch` | bool | **Desbloquea el menú de equipamiento** |
| `hasNotes` | bool | Posee las notas |
| `hasBoots` | bool | Posee las botas |
| `hasPlunger` | bool | Posee la sopapa |

#### Claves válidas para `PlayerData.skills` (via notes)

| Clave | Tipo | Efecto |
|---|---|---|
| `canFlash` | bool | Habilidad Light Burst (linterna) |
| `canDash` | bool | Habilidad Dash (botas) |
| `canPlungerang` | bool | Habilidad Plungerang |
| `canDance` | bool | Habilidad de bailar (DanceScene) |

> Ambas tablas son extensibles: cualquier clave/valor puede ser granteado aunque no esté pre-definido en `PlayerDataTables.lua`.

#### Generación condicional de ítems

Al cargar la escena (`MazeScene.lua` líneas ~180-254), los ítems solo se spawnan si el jugador **no los tiene ya**:

```lua
-- Para ítems con grants: no spawnear si ya tiene CUALQUIER clave granteada
if cf.grants then
  shouldGenerate = true
  for pair in string.gmatch(cf.grants, "([^,]+)") do
    local key, value = string.match(pair, "([^:]+):([^:]+)")
    if key then
      key = key:gsub("%s+", "")
      if PlayerData.items[key] == true or PlayerData.skills[key] == true then
        shouldGenerate = false
        break
      end
    end
  end
end

-- Para ítems estándar (lamp, boots, etc.): verificación directa
local itemRequirements = {
  lamp    = "items.hasLamp",
  boots   = "items.hasBoots",
  plunger = "items.hasPlunger",
  radio   = "items.hasRadio",
  notes   = "items.hasNotes",
}
```

### 4. Flujo Completo de Recolección

Cuando el jugador colisiona con un ítem (`entities/player/collisions.lua`):

1. `other:removeAll()` — desactiva `FXsonar` y elimina el sprite de la escena.
2. Se llama la función `grab*()` correspondiente (`entities/player/items.lua`):

```lua
-- Ítems estándar (hardcodeados):
Player:grabBoots()    → items.hasBoots = true, skills.canDash = true, fillBattery()
Player:grabPlunger()  → items.hasPlunger = true, skills.canPlungerang = true, fillBattery()
Player:grabLamp()     → items.hasLamp = true, skills.canFlash = true, fillBattery()
Player:grabRadio()    → items.hasRadio = true
Player:grabKey(n)     → keys[n] = true

-- Ítems dinámicos (via grants):
Player:grabNotes(grants)    → processGrants(grants, PlayerData.skills)
Player:grabItemGift(grants) → processGrants(grants, PlayerData.items)
```

3. `PlayerData` queda actualizado y el ítem ya no se regenera en esa habitación.

**Flujo de vida completo:**
```
LDtk (levels.lua) → MazeScene carga ítems → spawn condicional
→ Items(x, y, type, ...) con FXsonar activo
→ Jugador toca el ítem → collisionResponse()
→ removeAll() + grab*() → PlayerData actualizado
→ Habilidad disponible en menú (si hasDWatch == true)
```

### 5. Estado inicial de PlayerData (ítems y skills)

Definido en `assets/data/PlayerDataTables.lua`:

```lua
items = {
  hasLamp    = false,
  hasRadio   = true,    -- el jugador comienza con la radio
  hasDWatch  = false,   -- clave para el menú de equipamiento
  hasNotes   = true,    -- comienza con las notas
  hasBoots   = false,
  hasPlunger = false,
},
skills = {
  canFlash      = false,
  canDash       = false,
  canPlungerang = false,
  -- canDance se agrega dinámicamente via grants
},
keys = {}    -- se pobla con keys[n] = true al recoger keycards
```

> **Nota crítica:** `hasDWatch` es el gate del menú de equipamiento. Sin él, mantener A no abre nada.

### 6. FXsonar
Items emit a visual **FXsonar** ping — a pulsing circle that radiates outward from the item's position. This helps players locate items in dark or visually noisy rooms.
- Sonar is active while the item exists and is disabled via `removeAll()` on collection.
- **Love2D equivalent**: Animated circle with alpha oscillation (e.g., `love.graphics.circle("line", x, y, radius)` where radius and alpha cycle over time).

---

## 🖼️ PropItem System

Props represent interactive furniture and environmental details.

### 1. Visuals and States
Props share a single image sheet (`props.png`) with animation states like `chair`, `table`, `microwave`, `fridge`, etc.
- **Debris**: When destroyed, state changes to `debris`.
- **Z-Index**: Updated every frame based on Y position (pseudo-3D depth sort), unless "flat" (blood, holes) or special (minifiers).
- **Configuration**: `PropItem:init` uses a centralized `propConfigs` table for colliders, `isEdible`, `isHole`, `isSlime` flags, and Z-Index overrides.

### 2. Environmental Hazards & Utility

- **Holes**: Prop types like `holeCenter`, `holeLeft`, etc.
    - **Falling**: Without boots/battery → `self:fallBelow()`.
    - **Walking with boots**: Player drains battery (amount — verify exact value in `entities/player/collisions.lua`).

- **Minifiers**: Two-stage interaction requiring the physical crank:
    1. Standing on minifier → shows "Press A" prompt.
    2. A press → centers player, locks movement (`isGaming = false`).
    3. Crank counter-clockwise → shrink; clockwise → restore normal size.
    4. B press at any time → cancels and restores movement.
    5. Target size reached → movement restored automatically.

- **Slime (Tile IDs 89–97)**: Detected via the **tilemap**, not prop entities.
    - Detection: `GetTileUnderPlayer()` samples tile ID under player's 16×16 footprint.
    - Sliding immunity: `PlayerData.items.hasPlunger == true` → `checkSlimeTile()` returns early.
    - Full sliding mechanics in [PROPS_AND_ITEMS.md slime section below] and cross-referenced in [TILE_LOADING.md](TILE_LOADING.md).

    **Sliding Behavior**:
    - `isSliding = true` locks all directional input.
    - `slidingSpeed = 4` (faster than walk, slower than dash).
    - Direction-based animation states: `slideRight`, `slideDown`, `slideTiny` (if tiny).
    - Stops on tile departure OR wall collision.
    - Exit animations: `slideExitRight`, `slideExitLeft`, `slideExitUp`, `slideExitDown` (or `idle()` if tiny).
    - **`slideHitWall`** flag: set if wall hit while still on slime — prevents re-triggering the slide. Cleared when player presses a new directional key.

### 3. Destruction & Persistence
- **`destroyProp(id)`**: Uses LDtk IID to mark prop as destroyed in `levelsLDTK` (in-memory). Persisted by SaveSystem via IID match.
- **Persistence**: `MazeScene.lua` checks `destroyed` custom field on spawn.

---

## 👥 Entity Interactions

- **CrewMember**:
    - **Solid**: Slides against chairs, tables, walls, enemies.
    - **Pass-through**: Minifier pods, blood, debris, keycards, triggers.
- **Enemies (Brocorat)**: May eat edible props if `powerLevel` is high enough → destroys prop, gains power.

> [!TIP]
> Items use `FXsonar` to ping their location. See FXsonar note above for porting details.

---

## 🛠️ Love2D Porting Guide

### 1. Sprite System (`NobleSprite` → Love2D class)
- Use a class library (`middleclass`, `classic`, etc.) for `PropItem`.
- Store props in a table (`scene.props`) and iterate in `love.draw()`.
- **Animation**: Use `anim8` with a sprite atlas. Load `props.png` once, define frames as `Quad`s on a grid (mostly 32×32).

### 2. Item Management
- Load `items-key-table-32-32.png` once; use `love.graphics.newQuad` for each 3-frame animation range.
- Collision via bump.lua: on overlap, `world:remove(item)` + `table.remove(scene.items, i)`.

### 3. Collision System (bump.lua)
- Props: `world:add(prop, prop.x, prop.y, prop.w, prop.h)`.
- Use `propConfigs` table exactly as-is — it is pure data, engine-agnostic.

### 4. Z-Indexing (Depth Sorting)
```lua
table.sort(scene.entities, function(a, b)
    return a.y + a.height < b.y + b.height
end)
```
Static Z-index props (holes, rugs): force to a low layer — always draw first.

### 5. Slime Sliding (Tile-Based)
```lua
local SLIME_TILE_IDS = {}
for i = 89, 97 do SLIME_TILE_IDS[i] = true end

function Player:checkSlimeTile(tileData)
    if self.isSliding or self.isDashing then return end
    if PlayerData.items.hasPlunger then return end  -- immune

    local id = getTileAt(tileData, self.x, self.y)
    if id and SLIME_TILE_IDS[id] then
        self:startSliding(PlayerData.direction)
    end
end

function Player:updateSliding(tileData, world)
    if not self.isSliding then return end
    local dx, dy = 0, 0
    if     self.slideDir == "left"  then dx = -self.slideSpeed
    elseif self.slideDir == "right" then dx =  self.slideSpeed
    elseif self.slideDir == "up"    then dy = -self.slideSpeed
    elseif self.slideDir == "down"  then dy =  self.slideSpeed
    end
    local actualX, actualY, cols, len = world:move(self, self.x+dx, self.y+dy, self.collisionFilter)
    self.x, self.y = actualX, actualY
    local tileId = getTileAt(tileData, actualX, actualY)
    if len > 0 or not (tileId and SLIME_TILE_IDS[tileId]) then
        self:endSliding(len > 0)
    end
end

function Player:endSliding(hitWall)
    self.isSliding = false
    self.slideDir = nil
    PlayerData.direction = "idle"
    if hitWall then self.slideHitWall = true end
    -- trigger exit animation here
end
```
**Handling `slideHitWall`**: Reset `self.slideHitWall = false` when the player presses a directional key.

### 6. Crank (Minifier) Remapping
- **Mouse**: Scroll wheel up/down.
- **Keyboard**: Q/E or L/R triggers on gamepad.
- Replace crank UI indicator with "Scroll" or trigger button prompt.

### 7. propConfigs
Copy the `propConfigs` table exactly as-is. It is pure data and engine-agnostic. Use it in Love2D's `PropItem` constructor to set `isHole`, collision rects, etc.

### 8. Holes
In Love2D: if player center is within a Hole bounding box, trigger `fallBelow()`.
