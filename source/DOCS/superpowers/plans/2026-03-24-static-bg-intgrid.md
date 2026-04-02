# Static Background + IntGrid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separar visual de gameplay: fondo estático PNG por habitación + capa IntGrid para colisiones/interactividad. Permite usar auto-tiling de LDtk para crear niveles más rápido.

**Architecture:** LDtk exporta `BGTilemap.png` por habitación (ya lo hace) y una capa IntGrid con valores semánticos (0=piso, 1=pared, 2=slime, 3=hole). La React app genera un zip con los PNGs organizados + `tilemap.lua` con los valores IntGrid + los `levels_floorN.lua` ya existentes. MazeScene carga el PNG en lugar de construir el tilemap. `CreateTileColliders`, `IsPlayerOnSlime`, `IsPlayerOnHole` leen los valores IntGrid en vez de listas de tile IDs visuales.

**Tech Stack:** Lua, Playdate SDK, Noble Engine, LDtk, React export app.

**No test runner** — validar con `pdc` + Playdate Simulator.

---

## Contexto: estructura actual vs nueva

### Actual
```
tileMapData[customFields.tile] = matriz 25×15 de tile IDs visuales (5, 9, 51, 42...)
Config.Tiles.walkable = {lista de 28 tile IDs}
Config.Tiles.slime    = {89,90,...,98}
Config.Tiles.hole     = {104,...,115}
MazeScene → renderTileMap() + Graphics.tilemap → visual dinámico
```

### Nueva
```
tileMapData[customFields.tile] = matriz 25×15 de IntGrid (0=piso, 1=pared, 2=slime, 3=hole)
Config.Tiles.IntGrid = { wall=1, slime=2, hole=3 }
MazeScene → Graphics.image.new(BGTilemap.png) → visual estático
Lógica de colisión/slime/hole: comparar valor == 1/2/3 en vez de lookup en lista
```

---

## Pre-requisito (manual, en LDtk)

- [ ] En el proyecto LDtk, agregar una nueva capa de tipo **IntGrid** con nombre `Gameplay` con estos valores definidos:
  - `1` = Wall (pared)
  - `2` = Slime
  - `3` = Hole
  - `0` = Floor (vacío, valor por defecto cuando no se pinta nada)
- [ ] Pintar la capa `Gameplay` en cada habitación para que represente exactamente lo que hoy está en `tileMapData` (paredes en 1, slimes en 2, holes en 3).
- [ ] Verificar que la capa `BGTilemap` ya exporta un PNG por habitación en una carpeta con el nombre del room (e.g. `Room_1/BGTilemap.png`).

> El `BGTilemap.png` ya existe — solo necesitas la capa IntGrid nueva.

---

## File Map

| Archivo | Cambio |
|---|---|
| `source/assets/data/Config.lua` | Reemplazar `walkable/slime/hole` por `IntGrid = {wall=1, slime=2, hole=3}` |
| `source/utilities/Utilities.lua` | Simplificar `CreateTileColliders`, `IsPlayerOnSlime`, `IsPlayerOnHole`; eliminar hash tables |
| `source/scenes/MazeScene.lua` | Cargar PNG en vez de construir tilemap |
| `source/assets/data/tilemap.lua` | Regenerado por React app con valores IntGrid |
| `source/assets/data/levels_floor4.lua` | Regenerado por React app (sin cambios de estructura) |
| `source/assets/data/levels_floor3.lua` | Regenerado por React app (sin cambios de estructura) |
| `source/assets/images/rooms/floor4/*.png` | **Nuevos** — BGTilemap.png de cada room del floor 4 |
| `source/assets/images/rooms/floor3/*.png` | **Nuevos** — BGTilemap.png de cada room del floor 3 |

---

## Instrucciones para la React App

La React app debe generar un zip con todos los assets listos para soltar sobre `source/assets/`.

### Input que necesita la React App

1. **El archivo `.ldtk`** (o su JSON exportado) — contiene:
   - `levels[]` — cada nivel/room con sus capas
   - En cada nivel: capa `Gameplay` (IntGrid) con `intGridCsv` (array flat row-major)
   - En cada nivel: `customFields` con `level` (número de floor) y `tile` (índice en tileMapData)
2. **La carpeta de export de LDtk** — contiene subcarpetas `Room_1/`, `Room_2/`, etc., cada una con `BGTilemap.png`

### Output: estructura del zip

```
export.zip
  assets/
    data/
      tilemap.lua          ← generado desde IntGrid
      levels_floor4.lua    ← ya existente, sin cambios de formato
      levels_floor3.lua    ← ya existente, sin cambios de formato
    images/
      rooms/
        floor4/
          Room_1.png       ← copiado desde Room_1/BGTilemap.png
          Room_2.png
          ...
          Room_15.png
        floor3/
          Room_23.png
          Room_27.png
          Room_28.png
```

### Cómo generar `tilemap.lua`

La estructura debe ser **idéntica a la actual** — un array indexado por el valor de `customFields.tile` de cada room — pero con valores IntGrid en vez de tile IDs visuales.

```lua
-- tilemap.lua generado
tileMapData = {
    -- 1  (customFields.tile == 1 → Room_1)
    {
      {1,1,1,1,1,1,1,1,...},   -- fila 1: todo pared
      {1,0,0,0,0,0,0,0,...},   -- fila 2: pared izquierda, piso interior
      {1,0,0,2,2,0,0,0,...},   -- slime en columnas 4-5
      ...                       -- 15 filas × 25 columnas
    },
    -- 2  (customFields.tile == 2 → Room_2)
    {
      ...
    },
    ...
}
```

**Algoritmo para generar cada entrada:**
1. Para el room con `customFields.tile == N`, buscar la capa `Gameplay` (IntGrid)
2. Leer `intGridCsv` — es un array flat de 375 valores (25 cols × 15 rows)
3. Convertir a matriz 2D: `row[y][x] = intGridCsv[(y-1)*25 + (x-1) + 1]`
4. Insertar en `tileMapData[N]`

> El orden de los entries en `tileMapData` debe coincidir exactamente con los valores de `customFields.tile` de cada room (el índice actual se mantiene).

### Cómo organizar los PNGs

Para cada room en `levelsLDTK`:
1. Leer `identifier` (e.g. `"Room_1"`) y `customFields.level` (e.g. `4`)
2. Buscar el archivo `{ldtk_export_folder}/{identifier}/BGTilemap.png`
3. Incluirlo en el zip como `assets/images/rooms/floor{level}/{identifier}.png`

**Ejemplo:**
- `Room_1/BGTilemap.png` → `assets/images/rooms/floor4/Room_1.png`
- `Room_23/BGTilemap.png` → `assets/images/rooms/floor3/Room_23.png`

---

## Task 1 — Actualizar Config.lua

**Files:**
- Modify: `source/assets/data/Config.lua`

Reemplazar las tres listas de tile IDs por valores semánticos IntGrid. Esto simplifica toda la lógica de detección.

- [ ] **Step 1: Reemplazar el bloque `Config.Tiles`**

```lua
-- Tilemap
Config.Tiles = {
    size    = 16,
    IntGrid = {
        wall  = 1,
        slime = 2,
        hole  = 3,
        -- 0 = floor (vacío, default)
    }
}
```

- [ ] **Step 2: Compilar**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: errores en Utilities.lua (referencias a `Config.Tiles.walkable/slime/hole` — se arreglan en Task 2).

- [ ] **Step 3: Commit**

```bash
git add source/assets/data/Config.lua
git commit -m "refactor: replace tile ID lists with IntGrid semantic values in Config"
```

---

## Task 2 — Simplificar Utilities.lua

**Files:**
- Modify: `source/utilities/Utilities.lua`

Eliminar los hash tables de tile IDs y simplificar las tres funciones de detección.

### Contexto: qué existe hoy

```lua
-- Hash tables para lookup rápido (ahora innecesarios)
local SECTION_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.walkable) do
    SECTION_TILE_IDS[id] = true
end

SLIME_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.slime) do
    SLIME_TILE_IDS[id] = true
end

HOLE_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.hole) do
    HOLE_TILE_IDS[id] = true
end
```

### 2a — `CreateTileColliders`: cambiar condición de pared

Buscar en `CreateTileColliders` la línea:
```lua
if not SECTION_TILE_IDS[tileID] then
```
Reemplazar por:
```lua
if tileID == Config.Tiles.IntGrid.wall then
```

- [ ] **Step 1: Hacer el reemplazo en `CreateTileColliders`**

### 2b — `IsPlayerOnSlime`: cambiar condición

Buscar:
```lua
if tileID and SLIME_TILE_IDS[tileID] then
```
Reemplazar por:
```lua
if tileID == Config.Tiles.IntGrid.slime then
```

- [ ] **Step 2: Hacer el reemplazo en `IsPlayerOnSlime`**

### 2c — `IsPlayerOnHole`: cambiar condición

Buscar:
```lua
if tileID and HOLE_TILE_IDS[tileID] then
```
Reemplazar por:
```lua
if tileID == Config.Tiles.IntGrid.hole then
```

- [ ] **Step 3: Hacer el reemplazo en `IsPlayerOnHole`**

### 2d — Eliminar los hash tables

Eliminar los tres bloques de inicialización de hash tables:

```lua
-- ELIMINAR todo esto:
local SECTION_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.walkable) do
    SECTION_TILE_IDS[id] = true
end

SLIME_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.slime) do
    SLIME_TILE_IDS[id] = true
end

HOLE_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.hole) do
    HOLE_TILE_IDS[id] = true
end
```

- [ ] **Step 4: Eliminar los hash tables**

- [ ] **Step 5: Compilar**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add source/utilities/Utilities.lua
git commit -m "refactor: simplify tile detection to use IntGrid values"
```

---

## Task 3 — Actualizar MazeScene para cargar PNG

**Files:**
- Modify: `source/scenes/MazeScene.lua`

Reemplazar el bloque de construcción del tilemap por carga del PNG estático.

### Contexto: bloque actual (líneas 109–124)

```lua
-- MARK: Floor
tilesMap = Graphics.imagetable.new('assets/images/tile/tile')
map = Graphics.tilemap.new()
map:setImageTable(tilesMap)

renderTileMap(tileMapData[PlayerData.actualTilemap], map)

floor = Graphics.sprite.new()
floor:setZIndex(1)
floor:setTilemap(map)
floor:moveTo(0, 0)
floor:setCenter(0, 0)
floor:add()
```

### Nuevo bloque

```lua
-- MARK: Floor
local roomBgPath = 'assets/images/rooms/floor' .. PlayerData.actualLevel
                   .. '/' .. levelsLDTK[room].identifier
floor = Graphics.sprite.new()
floor:setImage(Graphics.image.new(roomBgPath))
floor:setZIndex(1)
floor:moveTo(200, 120)  -- centro de la pantalla (400/2, 240/2)
floor:add()
```

- [ ] **Step 1: Reemplazar el bloque de Floor en `scene:enter()`**

- [ ] **Step 2: Verificar que `floor:remove()` en `scene:exit()` sigue funcionando** — no requiere cambios, el sprite se remueve igual.

- [ ] **Step 3: Compilar**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: no errors (puede haber warning de `renderTileMap` unused si está definida en otro archivo).

- [ ] **Step 4: Commit**

```bash
git add source/scenes/MazeScene.lua
git commit -m "feat: load static PNG background per room instead of dynamic tilemap"
```

---

## Task 4 — Reemplazar tilemap.lua + agregar PNGs

Este task se ejecuta una vez que la React app genera el zip.

- [ ] **Step 1: Exportar desde la React app** — genera el zip con `tilemap.lua` (valores IntGrid) + PNGs organizados.

- [ ] **Step 2: Descomprimir el zip sobre `source/assets/`** — sobreescribe `data/tilemap.lua`, crea las carpetas `images/rooms/floor4/` y `images/rooms/floor3/`.

- [ ] **Step 3: Verificar estructura**

```bash
ls source/assets/images/rooms/floor4/
# Expected: Room_1.png Room_2.png ... Room_15.png

ls source/assets/images/rooms/floor3/
# Expected: Room_23.png Room_27.png Room_28.png
```

- [ ] **Step 4: Verificar tilemap.lua** — abrir `source/assets/data/tilemap.lua` y confirmar que los valores son 0/1/2/3, no tile IDs visuales como 5, 9, 51.

- [ ] **Step 5: Compilar + smoke test en simulador**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```

Entrar a varias habitaciones y confirmar:
- [ ] Fondo visual correcto (PNG carga bien)
- [ ] Paredes tienen colisión (no puedes atravesarlas)
- [ ] Slime tiles siguen causando sliding
- [ ] Hole tiles siguen causando caída
- [ ] Las puertas funcionan
- [ ] Guardar y recargar → misma habitación

- [ ] **Step 6: Commit**

```bash
git add source/assets/data/tilemap.lua \
        source/assets/images/rooms/
git commit -m "feat: add IntGrid tilemap.lua and static room PNG backgrounds"
```

---

## Verificación final

- [ ] `pdc` compila sin errores
- [ ] 18 habitaciones cargan correctamente
- [ ] Ningún tile visual en `tileMapData` (solo 0/1/2/3)
- [ ] Colisiones funcionan en todas las habitaciones
- [ ] Slime y hole tiles funcionan
- [ ] No hay referencias a `Config.Tiles.walkable`, `SLIME_TILE_IDS`, `HOLE_TILE_IDS` en el código

---

## Workflow futuro (para cada nuevo floor)

Cuando se exporte un nuevo floor desde LDtk:
1. Pintar capa `Gameplay` (IntGrid) + capa visual con auto-tiling
2. Exportar desde la React app → nuevo zip
3. Descomprimir sobre `source/assets/`
4. Agregar `import 'assets/data/levels_floorN'` al orquestador `levels.lua`
5. Compilar y verificar
