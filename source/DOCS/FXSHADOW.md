# FXshadow — Sistema de Oscuridad e Iluminación

Este documento describe en detalle cómo funciona `FXshadow` en el juego original (Playdate) y cómo portarlo a Love2D.

Archivo fuente: `entities/FX/FXshadow.lua`

---

## 🏗️ Arquitectura general

`FXshadow` es un sprite que cubre **toda la pantalla** (400×240) y actúa como una máscara de oscuridad encima del mundo de juego. Solo existe en habitaciones donde `levelsLDTK[room].customFields.shadow == true`.

Está formado por **tres capas dibujadas sobre una misma imagen**:

| Capa | Qué dibuja | Cobertura |
|---|---|---|
| **Global darkness** | Rectángulo negro con dithering en toda la pantalla | 400×240 siempre |
| **Primary mask** | Zona iluminada principal (círculo o polígono cónico) centrada en el jugador | Radio variable (`maskSize`) |
| **Focus light** | Foco pequeño adicional centrado en el jugador | Radio fijo (`lightSourceSize`, ~15–35px) |

El resultado es: pantalla oscurecida → área clara amplia → foco más intenso al centro.

---

## 🔧 Inicialización

```lua
-- En MazeScene:enter() si cf.shadow == true:
local lightLevel = cf.light or 0   -- float 0.0–1.0 desde LDtk
shadow = FXshadow(player, 70, lightLevel, ZIndex.fx)
PlayerData.isInDarkness = true
```

### Parámetros del constructor

| Parámetro | Descripción |
|---|---|
| `player` | Referencia al sprite del jugador (para leer posición en cada frame) |
| `lightSize` | Radio base del área iluminada principal. **Siempre se pasa `70`** en el juego. |
| `globalLightAmount` | Dithering base de la oscuridad global. Viene de `cf.light` en LDtk (0.0 = totalmente transparente, 1.0 = negro sólido). Salas muy oscuras usan valores cercanos a 1. |
| `Zindex` | `ZIndex.fx` — se dibuja encima de todo excepto la UI. |

### Variables de estado

```lua
self.lastBattery = -1
self.lastDirection = ""
self.lastPlayerX = -1
self.lastPlayerY = -1
self.lastLightSizeMulti = -1
self.lastGlobalLightAmountValue = -1
self.lastShowLightConeValue = false
self.shouldRefresh = true   -- fuerza redibujado en el primer frame
```

Estas variables implementan el **dirty-flag**: si ninguna cambia entre frames, `refresh()` retorna inmediatamente sin redibujar.

---

## 🔄 Ciclo de actualización

```
FXshadow:update()
    └─ FXshadow:refresh()
            ├─ Lee PlayerData.battery * 2   → 'battery' (escala interna 0–200)
            ├─ Lee PlayerData.direction      → dirección actual
            ├─ Lee PlayerData.x / .y         → posición del jugador
            ├─ Calcula lightSizeMulti        → 0.5 si isTiny, 1.0 si normal
            ├─ Compara con valores 'last*'   → dirty-flag check
            │       Si nada cambió → return (no redibuja)
            ├─ Actualiza variables 'last*'
            ├─ Calcula parámetros de luz según battery + hasLamp
            ├─ Construye polígono de cono si direction != 'idle'
            ├─ Dibuja capa global (dither full-screen)
            ├─ Dibuja capa primaria (máscara: círculo o polígono)
            └─ Dibuja foco secundario (círculo pequeño)
```

`refresh()` también es llamado directamente desde `MazeScene` en cada evento de movimiento:

```lua
-- MazeScene input handlers:
shadow:move(direction)   -- en movimiento del jugador
shadow:refresh()         -- en dash, plunge, y otros eventos de estado
```

`FXshadow:move()` actualiza `self.direction` y llama `refresh()`. No mueve el sprite (está centrado fijo en 200,120 — cubre toda la pantalla).

---

## 🔋 Escalado de battery

```lua
local battery = PlayerData.battery * 2   -- 0–100 → 0–200
```

`PlayerData.battery` va de 0 a 100. Se multiplica por 2 internamente para tener más resolución en los tiers de iluminación. **Todos los thresholds en `refresh()` operan sobre este valor escalado (0–200)**.

---

## 💡 Tiers de iluminación (con lámpara)

Condición previa: `PlayerData.items.hasLamp == true`.

| battery×2 | maskSize ajuste | lightAmount | lightSourceSize | lightSourceAmount | globalLightAmount |
|---|---|---|---|---|---|
| `> 160` | sin cambio (`-0`) | `self.globalLightAmount` (base) | `35` | `0` | base (`cf.light`) |
| `120 < x ≤ 160` | `- decreaseSize × 1` | `0.2` | `35` | `0.1` | `0.08` |
| `80 < x ≤ 120` | `- decreaseSize × 2` | `0.5` | `30` | `0.3` | `0.06` |
| `40 < x ≤ 80` | `- decreaseSize × 3` | `0.7` | `25` | `0.0` | `0.04` |
| `0 < x ≤ 40` | `- decreaseSize × 4` | `0.9` | `20` | `0.7` | `0.02` |
| `≤ 0` | `- decreaseSize × 5` | `1.0` | `15` | `0.9` | `0.01` |

Donde:
```lua
maskSize     = self.lightSize * lightSizeMulti   -- base: 70 * 1.0 = 70
decreaseSize = maskSize / 10                     -- 7px por tier
```

En el tier máximo (`> 160`) no hay branch explícito — los valores inicializados antes del bloque if/elseif se mantienen:
- `lightAmount = self.globalLightAmount` (dither base de la sala)
- `lightSourceAmount = 0`
- `lightSourceSize = 35`

### Sin lámpara

```lua
-- No lamp branch:
maskSize         = 50
lightAmount      = 1.0   -- máscara completamente negra (sin transparencia)
lightSourceSize  = 15
lightSourceAmount = 0.9  -- foco casi negro
```

El jugador ve un círculo de radio 50px casi completamente oscuro — prácticamente ciego sin lámpara en salas oscuras.

### Modo tiny

```lua
local lightSizeMulti = PlayerData.isTiny == true and 0.5 or 1
maskSize = self.lightSize * lightSizeMulti   -- 70 * 0.5 = 35px en tiny
```

Jugador reducido → área iluminada a la mitad.

---

## 🔦 Polígono del cono de luz

Cuando `direction != 'idle'`, en lugar de un círculo se dibuja un **polígono de 9 puntos** que simula un cono de luz direccional.

### Parámetros del cono (movimiento normal)

```lua
local d = 90    -- distancia hacia adelante (en px)
local h = 8     -- mitad del ancho del cono (escala)
```

Para dirección `left` o `down`, `d` se invierte: `d = d * -1`.

Para `left`, hay un desplazamiento adicional: `centerX = -18` (usado solo en el foco secundario).

### Puntos del polígono (horizontal: left/right)

```lua
(ix,         iy          )   -- origen: posición del jugador
(ix+d,       iy - 4*h   )   -- borde del cono, arriba-adelante
(ix+1.1*d,   iy - 3.5*h )
(ix+1.2*d,   iy - 2*h   )
(ix+1.25*d,  iy          )   -- punta del cono (más adelante)
(ix+1.2*d,   iy + 2*h   )
(ix+1.1*d,   iy + 3.5*h )
(ix+d,       iy + 4*h   )   -- borde del cono, abajo-adelante
(ix,         iy          )   -- cierre al origen
```

Para dirección `up/down` los ejes X e Y se intercambian.

El cono tiene forma de **D asimétrica**: la punta llega hasta `ix + 1.25*d` (≈112px adelante), y el ancho en la base es `± 4*h = ± 32px`.

### Modo `idle`

Cuando el jugador está parado (`direction == 'idle'`), se usa un **círculo** en lugar del polígono:

```lua
Graphics.fillCircleAtPoint(self.player.x, self.player.y, maskSize)
```

---

## ⚡ Lightburst (Flash)

Cuando `PlayerData.showLightCone == true` **y** `PlayerData.items.hasLamp == true`:

```lua
d = 200   -- cono extendido (vs 90 normal)
h = 12    -- más ancho (vs 8 normal)

-- Todos los dithers forzados a cero → luz máxima:
lightAmount       = 0
lightSourceAmount = 0
globalLightAmount = 0
```

El polígono se recalcula con los nuevos `d` y `h`. El cono llega hasta ≈250px hacia adelante y tiene ≈96px de ancho en la base.

`shouldRefresh = true` se fuerza mientras `showLightCone == true`, garantizando redibujado cada frame durante el flash (aunque la posición no cambie).

El flash se activa vía `Player:lightBurst()` (`entities/player/lightburst.lua`):
- Requiere `PlayerData.activeItem == 1` (lámpara seleccionada) y `canFlash == true`.
- Cuesta 10 de battery.
- Cooldown: 1000ms.
- `showLightCone` se pone en `true`; se oculta automáticamente 1000ms después vía `lightConeHideTime` en `player:update()`.
- Ciega a enemigos/crewmembers dentro del cono por 60 frames.

---

## 🎨 Proceso de dibujado en Playdate

```lua
-- 1. Oscuridad global (full screen, dithered)
Graphics.pushContext(shadow)
    Graphics.setDitherPattern(globalDither, Graphics.image.kDitherTypeBayer8x8)
    Graphics.fillRect(0, 0, 400, 240)
Graphics.popContext()

-- 2. Máscara primaria (área iluminada)
shadow:addMask()
Graphics.pushContext(shadowMask)   -- shadowMask = shadow:getMaskImage()
    Graphics.setDitherPattern(lightAmount, Graphics.image.kDitherTypeBayer8x8)
    if direction == 'idle' then
        Graphics.fillCircleAtPoint(px, py, maskSize)
    else
        Graphics.fillPolygon(Light)
        Graphics.drawPolygon(Light)
    end
Graphics.popContext()

-- 3. Foco secundario (círculo pequeño más brillante)
shadow:addMask()
Graphics.pushContext(lightSource)  -- lightSource = shadow:getMaskImage()
    Graphics.setDitherPattern(lightSourceAmount, Graphics.image.kDitherTypeBayer8x8)
    if direction == 'idle' then
        Graphics.fillCircleAtPoint(px, py, lightSourceSize)
    else
        Graphics.fillCircleAtPoint(px + centerX, py, lightSourceSize - 8)
    end
Graphics.popContext()
```

Las máscaras de Playdate son imágenes en blanco/negro donde:
- **Negro** en la máscara = **opaco** en la imagen (la oscuridad se muestra).
- **Blanco** en la máscara = **transparente** (la luz pasa).

El dithering controla la "mezcla": `0.0` = totalmente transparente (luz), `1.0` = totalmente opaco (oscuridad).

---

## 🛠️ Porting a Love2D

### Estrategia general

En Love2D no hay sistema de máscaras por imágen. La técnica estándar es:

1. Dibujar el mundo de juego normalmente en un `Canvas`.
2. Dibujar la oscuridad en otro `Canvas` usando `setBlendMode('multiply')`.
3. Dibujar la zona iluminada en el Canvas de oscuridad con color blanco (que no modifica el canvas del mundo).

### Estructura de la clase

```lua
local FXshadow = {}
FXshadow.__index = FXshadow

function FXshadow.new(player, lightSize, globalLightAmount)
    local self = setmetatable({}, FXshadow)
    self.player = player
    self.lightSize = lightSize           -- 70 en el juego
    self.globalLightAmount = globalLightAmount  -- cf.light de LDtk (0.0–1.0)

    -- Dirty-flag state
    self.lastBattery = -1
    self.lastDirection = ""
    self.lastPlayerX = -1
    self.lastPlayerY = -1
    self.lastLightSizeMulti = -1
    self.lastShowLightCone = false
    self.shouldRefresh = true

    -- Canvas de oscuridad (400×240, dibujado encima del mundo)
    self.canvas = love.graphics.newCanvas(400, 240)

    self:refresh()
    return self
end
```

### Dirty-flag check

```lua
function FXshadow:needsRefresh()
    local battery = PlayerData.battery * 2
    local lsm = PlayerData.isTiny and 0.5 or 1
    local dir = PlayerData.direction
    local px, py = PlayerData.x, PlayerData.y
    local slc = PlayerData.showLightCone == true

    if self.shouldRefresh or
       battery ~= self.lastBattery or
       dir     ~= self.lastDirection or
       px      ~= self.lastPlayerX or
       py      ~= self.lastPlayerY or
       lsm     ~= self.lastLightSizeMulti or
       slc     ~= self.lastShowLightCone then

        self.lastBattery        = battery
        self.lastDirection      = dir
        self.lastPlayerX        = px
        self.lastPlayerY        = py
        self.lastLightSizeMulti = lsm
        self.lastShowLightCone  = slc
        self.shouldRefresh      = false
        return true
    end
    return false
end
```

### Cálculo de parámetros (idéntico al original)

```lua
function FXshadow:calcParams()
    local battery = PlayerData.battery * 2
    local lightSizeMulti = PlayerData.isTiny and 0.5 or 1
    local maskSize = self.lightSize * lightSizeMulti   -- 70 * lsm
    local decreaseSize = maskSize / 10

    local lightAmount      = self.globalLightAmount
    local lightSourceAmount = 0
    local lightSourceSize  = 35
    local globalLightAmount = self.globalLightAmount

    if PlayerData.items.hasLamp then
        if battery > 160 then
            -- no change (default values above)
        elseif battery > 120 then
            maskSize -= decreaseSize * 1
            lightAmount = 0.2; lightSourceSize = 35; lightSourceAmount = 0.1; globalLightAmount = 0.08
        elseif battery > 80 then
            maskSize -= decreaseSize * 2
            lightAmount = 0.5; lightSourceSize = 30; lightSourceAmount = 0.3; globalLightAmount = 0.06
        elseif battery > 40 then
            maskSize -= decreaseSize * 3
            lightAmount = 0.7; lightSourceSize = 25; lightSourceAmount = 0.0; globalLightAmount = 0.04
        elseif battery > 0 then
            maskSize -= decreaseSize * 4
            lightAmount = 0.9; lightSourceSize = 20; lightSourceAmount = 0.7; globalLightAmount = 0.02
        else
            maskSize -= decreaseSize * 5
            lightAmount = 1.0; lightSourceSize = 15; lightSourceAmount = 0.9; globalLightAmount = 0.01
        end
    else
        maskSize = 50
        lightAmount = 1.0; lightSourceSize = 15; lightSourceAmount = 0.9
    end

    -- Lightburst override
    if PlayerData.showLightCone and PlayerData.items.hasLamp then
        lightAmount = 0; lightSourceAmount = 0; globalLightAmount = 0
        self.shouldRefresh = true   -- forzar redibujado cada frame
    end

    return {
        maskSize         = maskSize,
        lightAmount      = lightAmount,
        lightSourceSize  = lightSourceSize,
        lightSourceAmount = lightSourceAmount,
        globalLightAmount = globalLightAmount,
    }
end
```

### Construcción del polígono cónico

```lua
function FXshadow:buildLightCone(direction, d, h)
    local ix, iy = PlayerData.x, PlayerData.y
    if direction == 'left' or direction == 'down' then
        d = -d
    end

    local pts
    if direction == 'left' or direction == 'right' then
        pts = {
            ix,        iy,
            ix+d,      iy-4*h,
            ix+1.1*d,  iy-3.5*h,
            ix+1.2*d,  iy-2*h,
            ix+1.25*d, iy,
            ix+1.2*d,  iy+2*h,
            ix+1.1*d,  iy+3.5*h,
            ix+d,      iy+4*h,
            ix,        iy,
        }
    elseif direction == 'up' or direction == 'down' then
        pts = {
            ix,        iy,
            ix-4*h,    iy-d,
            ix-3.5*h,  iy-1.1*d,
            ix-2*h,    iy-1.2*d,
            ix,        iy-1.25*d,
            ix+2*h,    iy-1.2*d,
            ix+3.5*h,  iy-1.1*d,
            ix+4*h,    iy-d,
            ix,        iy,
        }
    end
    return pts   -- tabla de pares x,y para love.graphics.polygon
end
```

### `refresh()` completo

```lua
function FXshadow:refresh()
    if not self:needsRefresh() then return end

    local p  = self:calcParams()
    local dir = PlayerData.direction
    local px, py = PlayerData.x, PlayerData.y
    local centerX = (dir == 'left') and -18 or 0

    -- Parámetros del cono (normal vs lightburst)
    local d = (PlayerData.showLightCone and PlayerData.items.hasLamp) and 200 or 90
    local h = (PlayerData.showLightCone and PlayerData.items.hasLamp) and 12  or 8

    -- Construir polígono si no está en idle
    local conePts = nil
    if dir ~= 'idle' and dir ~= nil then
        conePts = self:buildLightCone(dir, d, h)
    end

    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 0)  -- limpiar canvas

    -- === Capa 1: oscuridad global ===
    -- globalLightAmount: 0.0 = transparent, 1.0 = solid black
    love.graphics.setColor(0, 0, 0, p.globalLightAmount)
    love.graphics.rectangle("fill", 0, 0, 400, 240)

    -- Para el resto usamos 'multiply' sobre lo ya dibujado:
    -- blanco = deja pasar la luz (no oscurece)
    -- negro = oscurece completamente
    -- Alternativa: dibujar con setBlendMode y alpha inverso

    -- === Capa 2: máscara primaria (área iluminada) ===
    -- lightAmount: 0.0 = totalmente iluminado, 1.0 = oscuro
    -- En Love2D: dibujamos el área clara con alpha = (1 - lightAmount)
    love.graphics.setBlendMode("subtract")  -- o usa un canvas separado con multiply
    love.graphics.setColor(0, 0, 0, 1 - p.lightAmount)
    if dir == 'idle' or conePts == nil then
        love.graphics.circle("fill", px, py, p.maskSize)
    else
        love.graphics.polygon("fill", conePts)
    end

    -- === Capa 3: foco secundario ===
    love.graphics.setColor(0, 0, 0, 1 - p.lightSourceAmount)
    local focusR = p.lightSourceSize - (dir ~= 'idle' and 8 or 0)
    love.graphics.circle("fill", px + centerX, py, focusR)

    love.graphics.setCanvas()
    love.graphics.setBlendMode("alpha")  -- restaurar
end
```

> [!WARNING]
> El modelo de blending de Love2D es diferente a las máscaras de Playdate. El enfoque recomendado es usar **dos canvas**: uno para el mundo, uno para la oscuridad con `setBlendMode('multiply')`. Ver la sección siguiente.

### Implementación recomendada con dos Canvas

```lua
-- En love.load:
worldCanvas    = love.graphics.newCanvas(400, 240)
darknessCanvas = love.graphics.newCanvas(400, 240)

-- En love.draw:
-- 1. Dibujar el mundo en worldCanvas
love.graphics.setCanvas(worldCanvas)
love.graphics.clear()
drawWorld()  -- tiles, enemigos, player, props...
love.graphics.setCanvas()

-- 2. Dibujar la oscuridad en darknessCanvas
if PlayerData.isInDarkness and fxshadow then
    love.graphics.setCanvas(darknessCanvas)
    love.graphics.clear(0, 0, 0, 1)   -- empezar todo negro

    -- Recortar zona iluminada dibujando blanco sobre negro
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1 - lightAmount)  -- blanco = transparente a negro
    if dir == 'idle' then
        love.graphics.circle("fill", px, py, maskSize)
    else
        love.graphics.polygon("fill", unpack(conePts))
    end
    love.graphics.setCanvas()

    -- 3. Componer: mundo × oscuridad
    love.graphics.draw(worldCanvas, 0, 0)
    love.graphics.setBlendMode("multiply")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(darknessCanvas, 0, 0)
    love.graphics.setBlendMode("alpha")
else
    love.graphics.draw(worldCanvas, 0, 0)
end
```

El modo `multiply` hace que:
- Píxeles blancos en `darknessCanvas` (`1,1,1`) → no modifican `worldCanvas`.
- Píxeles negros en `darknessCanvas` (`0,0,0`) → oscurecen completamente.
- Grises intermedios → oscurecen proporcionalmente.

### Dithering en Love2D

Playdate usa dithering Bayer 8×8 para simular grises en su pantalla 1-bit. En Love2D con display de color, el dithering no es necesario — usa alpha directamente. Si quieres replicar el look 1-bit:

```lua
-- Shader de dithering Bayer 8x8
local ditherShader = love.graphics.newShader([[
    extern float threshold;
    const mat4 bayerMatrix = mat4(
         0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,
        48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0,
        12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0,
        60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0
    );
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        int x = int(mod(sc.x, 4.0));
        int y = int(mod(sc.y, 4.0));
        float bayer = bayerMatrix[y][x];
        float alpha = threshold > bayer ? 0.0 : 1.0;
        return vec4(0.0, 0.0, 0.0, alpha);
    }
]])

-- Uso:
love.graphics.setShader(ditherShader)
ditherShader:send("threshold", globalLightAmount)
love.graphics.rectangle("fill", 0, 0, 400, 240)
love.graphics.setShader()
```

---

## 📋 Tabla de referencia rápida

| Variable | Fuente | Rango |
|---|---|---|
| `PlayerData.battery` | Estado global | 0–100 |
| `battery` interno | `battery * 2` | 0–200 |
| `lightSize` (constructor) | Hardcoded en MazeScene | `70` |
| `globalLightAmount` | `cf.light` en LDtk | 0.0–1.0 |
| `maskSize` base | `70 * lightSizeMulti` | 35–70px |
| `decreaseSize` | `maskSize / 10` | 3.5–7px |
| Cono normal: `d` | Hardcoded | `90` (o `-90` en left/down) |
| Cono normal: `h` | Hardcoded | `8` |
| Cono flash: `d` | Hardcoded | `200` |
| Cono flash: `h` | Hardcoded | `12` |
| Foco: `lightSourceSize` | Por tier | 15–35px |
| Foco idle radio | `lightSourceSize` | directo |
| Foco moving radio | `lightSourceSize - 8` | 7–27px |

---

## ⚠️ Notas para el port

1. **`shouldRefresh = true` durante lightburst**: La posición del jugador no cambia, pero el cono sí (es grande y activo). El flag garantiza que el polígono se recalcule cada frame durante el flash.

2. **`centerX = -18` solo para izquierda**: El foco secundario se desplaza 18px a la izquierda cuando el jugador mira en esa dirección. Es el único caso con offset.

3. **`drawPolygon` + `fillPolygon`**: El original llama ambos sobre el cono (relleno + borde). En Love2D `love.graphics.polygon("fill", ...)` rellena; añadir `love.graphics.polygon("line", ...)` si quieres el borde.

4. **El sprite está fijo en (200,120)**: No sigue al jugador — cubre toda la pantalla. La posición del jugador se lee de `PlayerData.x/y` directamente al dibujar.

5. **`FXshadow:move()` no mueve el sprite**: Solo actualiza `self.direction` y llama `refresh()`. El nombre es confuso — en el port no necesitas un método `move` separado; llama `refresh()` directamente.

6. **Tier `> 160` (batería alta)**: No hay un `if` explícito para este caso en el código fuente. Los valores por defecto definidos antes del bloque if/elseif se usan: `lightAmount = self.globalLightAmount`, `lightSourceAmount = 0`, `lightSourceSize = 35`. Esto significa que con batería alta y lámpara, la oscuridad global usa el dither base de la sala (puede ser baja, por ejemplo 0.08 en salas poco oscuras).
