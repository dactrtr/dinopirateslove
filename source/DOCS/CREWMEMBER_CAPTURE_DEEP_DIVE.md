# CrewMember: Sistema de Captura — Deep Dive

Documentación exhaustiva del comportamiento del `CrewMember` para el port a Love2D. Cubre inicialización, movimiento de huida, sistema de rebotes, estado de escondite, stuns, animaciones y la lógica de captura.

---

## 1. Inicialización

```lua
CrewMember(x, y, moveSpeed, Zindex, player, iid, room, crewId)
```

### Propiedades clave al crear

| Propiedad | Valor default | Descripción |
|---|---|---|
| Sprite asset | `assets/images/enemies/crewmember` | Imagetable, 48×48 px |
| `collideRect` | `(12, 24, 24, 24)` | Offset: bottom-center del sprite |
| `moveSpeed` | 1.5 (si nil) | Velocidad en píxeles por "frame activo" |
| `hatDelta` | 15 | Offset Y del sombrero sobre el sprite |
| `movementFrames` | 0 | Budget de movimiento (token system) |
| `bounceFrames` | 0 | Frames restantes de dirección de rebote |
| `recentBounceCount` | 0 | Contador de rebotes recientes |
| `bouncesRequiredToHide` | **2** | Rebotes necesarios para entrar en hiding |
| `bounceCountDecayRate` | 30 | Frames sin rebote para resetear el contador |
| `hidingVisionRange` | 80 px | Distancia mínima al player para salir de hiding |
| `hidingMovementTokensRequired` | **3** | Tokens acumulados para salir de hiding |
| `cornerDetectionThreshold` | 0.5 px | Diferencia mínima para detectar colisión |

### Grupos de colisión
- **Pertenece a**: `CollideGroups.crewMember`
- **Choca con**: `CollideGroups.props`, `CollideGroups.wall`, `CollideGroups.enemy`, `CollideGroups.crewMember`, `CollideGroups.player`

### El sombrero (`Hats`)
Al crear el CrewMember se instancia un sprite `Hats` separado:
```lua
self.hat = Hats(x, y - self.hatDelta, crewId, zIndex=2)
```
- Asset: `assets/images/props/hats` (imagetable, 20×16 px por frame)
- 21 estados estáticos (1 frame cada uno): `CM001`–`CM021`
- Se posiciona **siempre 15px por encima** del CrewMember
- Se mueve manualmente en `moveCollision`: `self.hat:moveTo(actualX, actualY - self.hatDelta)`
- Se oculta/muestra independientemente durante hiding y stun

---

## 2. Estados de Animación

| Estado | Frames | Duration | Cuándo activa |
|---|---|---|---|
| `walk` | 1–4 | 8 | Moviéndose (en `escape`) |
| `idle` | 5–8 | 6 | Sin movimiento, ni stun, ni hiding |
| `hide` | 12–13 | 6 | En estado de escondite |
| `stunned` | 15–18 | 6 | `stunInfinite()` activo |

> [!NOTE]
> Las animaciones se cambian **directamente en los puntos de decisión** (en `escape`, `enterHiding`, `exitHiding`, `stunInfinite`, `blind`, `update`). No hay máquina de estados centralizada — cada función setea el estado que le corresponde.

---

## 3. Loop de Update

```lua
function CrewMember:update()
    -- Throttle: ejecuta AI solo cada 2 frames
    self.updateFrameCounter = (self.updateFrameCounter + 1) % 2

    -- [1] Si está escondido → solo mantiene animación hide, no se mueve
    if self.isHiding then
        self.animation:setState('hide')
        return
    end

    -- [2] Si está cegado o stunneado infinitamente
    if self.isBlinded or self.isStunnedInfinitely then
        if self.isBlinded then
            self.blindFrames -= 1
            if self.blindFrames <= 0 then self.isBlinded = false end
        end
        if self.isStunnedInfinitely then
            self.animation:setState('stunned')
        end
        return  -- skip todo movimiento
    end

    -- [3] Procesar movimiento si hay budget
    if self.movementFrames > 0 then
        self.movementFrames -= 1
        if self.updateFrameCounter % 2 == 0 then
            self:search(self.player)  -- AI cada 2 frames
        end
    else
        self.animation:setState('idle')
    end
end
```

**Prioridad de estados (orden de evaluación):**
1. `isHiding` → override total, regresa inmediatamente
2. `isBlinded` o `isStunnedInfinitely` → freeze + animación, regresa
3. `movementFrames > 0` → ejecutar AI de huida (cada 2 frames)
4. Sin budget → idle

---

## 4. Sistema de Movimiento: Token Budget

El CrewMember no se mueve en cada frame sino solo cuando tiene "budget":

```
Player:move()  →  distributeMovementFrames(3)  →  crewMember.movementFrames += 3
B press        →  distributeMovementTokens(5)   →  crewMember.movementFrames += 150
```

Cada frame del update consume 1 frame de budget. El AI (`search`) se ejecuta solo cada 2 frames dentro de ese budget.

**Caso especial en hiding**: en lugar de acumular `movementFrames`, los tokens se acumulan en `hidingMovementTokensAccumulated` para decidir cuándo salir del escondite.

```lua
function CrewMember:addMovementTokens(amount)
    if self.isHiding then
        self.hidingMovementTokensAccumulated += amount
        self:checkExitHiding()
    else
        self.movementFrames += amount * 30  -- 1 token = 30 frames
    end
end

function CrewMember:addMovementFrames(frames)
    if self.isHiding then
        self.hidingMovementTokensAccumulated += frames / 30  -- convierte a tokens
        self:checkExitHiding()
    else
        self.movementFrames = math.min(self.movementFrames + frames, 90)  -- cap: 90 frames
    end
end
```

---

## 5. AI de Huida (`search` → `escape`)

```lua
function CrewMember:search(player)
    if not self:isPlayerOutOfVision() and not PlayerData.isTiny then
        self:escape(player)   -- player visible y no es tiny → huir
    else
        self.animation:setState('idle')  -- player lejos o tiny → quieto
    end
end
```

`isPlayerOutOfVision()` calcula distancia euclidiana con el player. Si `distance > hidingVisionRange (80px)` → true.

### escape(): el movimiento de huida

```lua
function CrewMember:escape(player)
    -- Modo rebote: moverse en dirección predeterminada
    if self.bounceFrames > 0 then
        self.bounceFrames -= 1
        movementX, movementY = <dirección de bounceDirection>
        if self.bounceFrames <= 0 then self.bounceDirection = nil end

    else
        -- Modo normal: alejarse del player en ambos ejes
        movementX = player.x <= self.x  and  self.x + moveSpeed  or  self.x - moveSpeed
        movementY = player.y <= self.y  and  self.y + moveSpeed  or  self.y - moveSpeed
    end

    self.animation:setState('walk')
    self:moveCollision(movementX, movementY, player)
end
```

**Dirección normal de huida:**
- Si player está a la izquierda (`player.x < self.x`) → moverse a la derecha
- Si player está a la derecha → moverse a la izquierda
- Si player está arriba (`player.y < self.y`) → moverse hacia abajo
- Si player está abajo → moverse hacia arriba

El CM intenta moverse en **diagonal** (ambos ejes simultáneamente) — no elige un eje, mueve X e Y cada frame.

---

## 6. Sistema de Rebotes y Detección de Esquinas

Este es el sistema más complejo. Se ejecuta dentro de `moveCollision` tras cada `moveWithCollisions`.

### 6.1 Detección de colisión

```lua
local blockedX = math.abs(actualX - movementX) > 0.5
local blockedY = math.abs(actualY - movementY) > 0.5
```

Si la posición real difiere de la objetivo en más de 0.5px, se considera que hubo una colisión en ese eje.

### 6.2 Decay del contador

Antes de procesar un nuevo rebote, se decrementa el timer de decay:
```lua
if self.bounceCountDecayFrames > 0 then
    self.bounceCountDecayFrames -= 1
else
    if self.recentBounceCount > 0 then
        self.recentBounceCount = 0  -- reset: demasiado tiempo sin rebotar
    end
end
```

### 6.3 Trigger de rebote (solo si no hay rebote activo)

```lua
if (blockedX or blockedY) and self.bounceFrames <= 0 then
    self.recentBounceCount += 1
    self.bounceCountDecayFrames = 30  -- reinicia el timer

    -- ¿Demasiados rebotes rápidos? → esconderse
    if self.recentBounceCount >= 2 then
        self:enterHiding()
        return
    end

    -- Calcular dirección de escape perpendicular
    local playerToLeft = player.x < self.x
    local playerBelow  = player.y > self.y

    if blockedX and blockedY then      -- esquina
        if math.random() > 0.5 then
            bounceDirection = playerBelow and 'up' or 'down'
        else
            bounceDirection = playerToLeft and 'right' or 'left'
        end
    elseif blockedX then               -- pared lateral
        bounceDirection = playerBelow and 'up' or 'down'
    elseif blockedY then               -- pared superior/inferior
        bounceDirection = playerToLeft and 'right' or 'left'
    end

    self.bounceFrames = 20
end
```

### Tabla de dirección de rebote

| Colisión | Player relativo | Dirección de rebote |
|---|---|---|
| Pared lateral (blockedX) | Player abajo | `up` |
| Pared lateral (blockedX) | Player arriba | `down` |
| Pared vertical (blockedY) | Player a la izquierda | `right` |
| Pared vertical (blockedY) | Player a la derecha | `left` |
| Esquina (ambos) | — | Aleatorio entre las dos opciones |

> [!IMPORTANT]
> Un rebote NO ocurre si `bounceFrames > 0` (rebote ya activo). El nuevo rebote solo se detecta al terminar el bounce actual. Esto evita cascadas de rebotes.

### Flujo visual del sistema de rebotes

```
Frame 1: CM choca con pared derecha
  → blockedX = true
  → recentBounceCount = 1  (no alcanza 2 → no hiding)
  → bounceDirection = 'up' (player está abajo)
  → bounceFrames = 20

Frames 2-21: CM se mueve hacia arriba (bounceFrames decrementa)
  (durante estos frames, aunque choque, bounceFrames > 0 así que no cuenta nuevo rebote)

Frame 22: bounceFrames = 0, bounceDirection = nil
  → CM vuelve a modo escape normal (diagonal)

Si en los próximos 30 frames choca de nuevo:
  → recentBounceCount = 2  ≥ bouncesRequiredToHide (2)
  → ENTERING HIDING

Si pasan 30 frames sin rebotar:
  → bounceCountDecayFrames llega a 0 → recentBounceCount = 0 (reset)
```

---

## 7. Estado de Escondite (Hiding)

### 7.1 Entrar en hiding (`enterHiding`)

```lua
function CrewMember:enterHiding()
    self.isHiding = true
    self.hidingMovementTokensAccumulated = 0

    self.animation:setState('hide')     -- frames 12-13

    self.hat:setVisible(false)          -- ocultar sombrero

    self:setCollideRect(0, 0, 0, 0)    -- QUITAR colisión completamente
    self:setGroups({})                  -- QUITAR de todos los grupos de colisión
end
```

Tras `enterHiding`, el CrewMember es **completamente invisible al sistema de colisiones**. El player no puede capturarlo. Visualmente sigue en pantalla (sprite `hide`), pero es intangible.

### 7.2 Condición de salida (`checkExitHiding`)

```lua
function CrewMember:checkExitHiding()
    if self:isPlayerOutOfVision()                                          -- distancia > 80px
    and self.hidingMovementTokensAccumulated >= 3 then                     -- Y suficientes tokens
        self:exitHiding()
    end
end
```

**Ambas condiciones son necesarias simultáneamente.** Si el player se aleja pero no ha habido suficiente actividad de movimiento, el CM permanece escondido.

La acumulación de tokens durante hiding viene de los mismos `distributeMovementFrames/Tokens` del player — el player tiene que moverse para que el contador suba.

### 7.3 Salir de hiding (`exitHiding`)

```lua
function CrewMember:exitHiding()
    self.isHiding = false
    self.hidingMovementTokensAccumulated = 0

    self.animation:setState('idle')

    self.hat:setVisible(true)

    -- Restaurar collider original
    self:setCollideRect(12, 24, 24, 24)

    -- ⚠️ NOTA: restaura a CollideGroups.enemy (no crewMember)
    -- Esto parece un bug en el código original — verificar en producción
    self:setGroups(CollideGroups.enemy)

    -- Reset del estado de rebote
    self.bounceDirection = nil
    self.bounceFrames = 0
end
```

> [!WARNING]
> Al salir de hiding, el grupo de colisión se restaura a `CollideGroups.enemy` (no a `CollideGroups.crewMember` como estaba originalmente). En el port a Love2D, evaluar si esto es intencional o un bug. Si el player solo colisiona con `crewMember`, el CM quedaría inalcanzable tras salir de hiding.

---

## 8. Estados de Stun

### 8.1 Stun temporal (`blind`)

```lua
function CrewMember:blind(frames)
    if self.isHiding then return end  -- inmune si está escondido

    self.blindFrames = frames or 60   -- default: 60 frames (~2 segundos)
    self.isBlinded = true
    self.movementFrames = 0           -- corta el movimiento inmediatamente
    self.animation:setState('idle')   -- no hay animación especial de blind
end
```

- El sombrero permanece visible
- Se decrementa `blindFrames` en cada frame del update
- Cuando llega a 0: `isBlinded = false` → el CM vuelve a moverse normalmente

### 8.2 Stun permanente (`stunInfinite`)

```lua
function CrewMember:stunInfinite()
    self.isStunnedInfinitely = true
    self.movementFrames = 0
    self.animation:setState('stunned')  -- frames 15-18
    self.hat:setVisible(false)          -- el sombrero se oculta
end
```

- **No hay manera de salir de este estado** excepto que sea capturado (`taken()`)
- El hat se oculta mientras está stunned
- El collider **permanece activo** — el player puede capturarlo
- Usado exclusivamente cuando el Plungerang golpea a un CrewMember

---

## 9. Colisión con el Player

Cuando el player choca con un CrewMember, `Player:collisionResponse(other)` maneja la interacción. Hay **dos paths completamente distintos**:

### Path A: Player en modo Tiny (`isTiny == true`)

```lua
if PlayerData.isTiny then
    self.currentTrigger = other   -- guarda referencia al CM
    return 'overlap'              -- el player pasa a través
end
```

El CrewMember no huye, no es capturado. Funciona como un trigger:
- `player.currentTrigger` apunta al CM
- El MazeScene detecta `currentTrigger` en su input handler
- Al presionar A, llama `crewMember:returnScript()` → busca `tinyScript` en LDtk, fallback a `<crewId>_tiny` o `"default_tiny"`
- Se abre el diálogo sin capturar al CM

### Path B: Player en modo Normal

```lua
-- Si es la primera captura de cualquier CM → mostrar diálogo especial
if PlayerData.CrewMemberData.amountTaken == 0 then
    self.dialogUI:addScreen("gotcha", other.sourceFeed)
end

-- Capturar inmediatamente (sin esperar que termine el diálogo)
other:taken()
```

> [!NOTE]
> La captura ocurre **inmediatamente** al tocar al CM en modo normal, independientemente del estado del CM (puede estar en walk, idle, o stunned — si el collider está activo, se captura). No hay sistema de "hasBag" activo actualmente — el check de `hasBag` no está implementado en este branch.

---

## 10. La Captura (`taken`)

```lua
function CrewMember:taken()
    -- 1. Encontrar este CM en levelsLDTK por IID
    local roomData = levelsLDTK[self.room]
    for _, crewData in ipairs(roomData.entities.CrewMember) do
        if crewData.iid == self.iid then
            -- 2. Marcar como capturado en el estado in-memory del nivel
            crewData.customFields.isTaken = true

            -- 3. Actualizar contador global
            PlayerData.CrewMemberData.amountTaken += 1

            -- 4. Registrar ID específico (para mostrar hat en el menú)
            if self.crewId then
                PlayerData.CrewMemberData.idNumbers[self.crewId] = true
            end

            -- 5. ⚠️ Restaurar el plungerang del player
            if self.player then
                self.player.hasProjectile = true
            end
            break
        end
    end

    -- 6. Eliminar sprites
    self:remove()
    if self.hat then self.hat:remove() end
end
```

> [!IMPORTANT]
> **`taken()` siempre restaura `player.hasProjectile = true`**, independientemente de cómo fue capturado el CM (no solo cuando fue stunned por el plungerang). Si el CM fue capturado por contacto directo sin usar el plungerang, el player aún recupera el projectile. Verificar si esto es intencional.

### Datos que persisten tras la captura

`customFields.isTaken = true` queda en la tabla in-memory `levelsLDTK`. Esto se guarda en el siguiente `SaveSystem.save()` (al salir de la habitación). Cuando se recarga, `MazeScene:enter` no spawnea CMs cuyo `customFields.isTaken == true`.

---

## 11. Respuesta de Colisión del CrewMember (`collisionResponse`)

Lo que DEVUELVE el CM cuando otro objeto choca contra él:

| Objeto que choca | Respuesta | Efecto |
|---|---|---|
| `Box` (pared) | `'slide'` | Se desliza a lo largo de la pared |
| `Enemy` (Brocorat, etc.) | `'slide'` | Se bloquea, activa bounce logic |
| `PropItem` tipo `minifier` | `'overlap'` | Pasa a través libremente |
| Cualquier otro `PropItem` | `'slide'` | Se bloquea (silla, mesa, etc.) |
| Todo lo demás | `'overlap'` | Pasa a través |

El `'slide'` es lo que activa la detección de `blockedX/blockedY` en `moveCollision` — el engine ajusta la posición y devuelve un `actualX/Y` diferente al objetivo.

---

## 12. Diagrama de Estado Completo

```
                    ┌──────────────────────────────────────┐
                    │              NORMAL                  │
                    │  movementFrames > 0 → search/escape  │
                    │  movementFrames = 0 → idle           │
                    └──────────────────────────────────────┘
                           │              │              │
              choca 2 veces           blind()      stunInfinite()
              en <30 frames           (Lightburst)  (Plungerang)
                    │                    │              │
                    ▼                    ▼              ▼
             ┌──────────┐          ┌─────────┐   ┌──────────┐
             │  HIDING  │          │ BLINDED │   │ STUNNED  │
             │          │          │  (timed)│   │(infinite)│
             │ invisible│          │         │   │ hat oculto│
             │ intangible│         │blindFrames   │          │
             │ hat oculto│         │ cuenta regresiva│       │
             └──────────┘          └─────────┘   └──────────┘
                    │                    │              │
         player > 80px               blindFrames=0  player toca
         + 3 tokens acumulados            │          → taken()
                    │                    ▼              │
                    ▼              vuelve a NORMAL      ▼
             vuelve a NORMAL                       ┌──────────┐
                                                   │ CAPTURED │
                                                   │ (removed)│
                                                   └──────────┘
```

---

## 13. Love2D — Guía de Implementación

### 13.1 Estructura de la clase

```lua
local CrewMember = {}
CrewMember.__index = CrewMember

function CrewMember.new(x, y, moveSpeed, crewId, iid, room, player)
    local self = setmetatable({}, CrewMember)
    self.x, self.y = x, y
    self.w, self.h = 48, 48
    -- Collide rect offset (relativo al origen del sprite)
    self.collideOffsetX = 12
    self.collideOffsetY = 24
    self.collideW = 24
    self.collideH = 24

    self.moveSpeed = moveSpeed or 1.5
    self.crewId = crewId
    self.iid = iid
    self.room = room
    self.player = player

    self.movementFrames = 0
    self.updateFrameCounter = math.random(0, 1)  -- throttle offset

    -- Estado
    self.state = "normal"   -- "normal" | "hiding" | "blinded" | "stunned"
    self.animState = "idle"

    -- Bounce system
    self.bounceFrames = 0
    self.bounceDirection = nil
    self.recentBounceCount = 0
    self.bounceCountDecayFrames = 0

    -- Hiding
    self.isHiding = false
    self.hidingTokensAccumulated = 0

    -- Stun
    self.isBlinded = false
    self.blindFrames = 0
    self.isStunnedInfinitely = false

    -- Hat: sprite separado
    self.hat = Hat.new(x, y - 15, crewId)

    -- bump.lua: registrar con rect de colisión
    bumpWorld:add(self,
        x + self.collideOffsetX,
        y + self.collideOffsetY,
        self.collideW,
        self.collideH)

    return self
end
```

### 13.2 Update loop

```lua
function CrewMember:update(dt)
    -- Throttle: solo cada 2 frames
    self.updateFrameCounter = (self.updateFrameCounter + 1) % 2

    -- [1] Hiding: inmóvil, solo acumula tokens
    if self.isHiding then
        self.animState = "hide"
        self.hat:setVisible(false)
        return
    end

    -- [2] Blinded: decrementar, sin movimiento
    if self.isBlinded then
        self.blindFrames = self.blindFrames - 1
        if self.blindFrames <= 0 then
            self.isBlinded = false
        end
        self.animState = "idle"
        return
    end

    -- [3] Stunned infinito: sin movimiento
    if self.isStunnedInfinitely then
        self.animState = "stunned"
        self.hat:setVisible(false)
        return
    end

    -- [4] Movimiento con budget
    if self.movementFrames > 0 then
        self.movementFrames = self.movementFrames - 1
        if self.updateFrameCounter % 2 == 0 then
            self:search()
        end
    else
        self.animState = "idle"
    end
end
```

### 13.3 Movimiento y detección de bloqueo (reemplaza moveWithCollisions)

```lua
function CrewMember:moveAndDetectBlock(goalX, goalY)
    local actualX, actualY, collisions, len = bumpWorld:move(
        self,
        goalX + self.collideOffsetX,
        goalY + self.collideOffsetY,
        self.collisionFilter
    )
    -- Convertir de vuelta a posición del sprite
    actualX = actualX - self.collideOffsetX
    actualY = actualY - self.collideOffsetY

    local THRESHOLD = 0.5
    local blockedX = math.abs(actualX - goalX) > THRESHOLD
    local blockedY = math.abs(actualY - goalY) > THRESHOLD

    self.x, self.y = actualX, actualY
    self.hat:moveTo(actualX, actualY - 15)

    -- Procesar colisiones con el player
    for _, col in ipairs(collisions) do
        if col.other.isPlayer then
            self.player:onCrewMemberCollision(self)
        end
    end

    return blockedX, blockedY
end
```

### 13.4 Collision filter (bump.lua)

```lua
function CrewMember:collisionFilter(other)
    if other.isWall or other.isSolidProp then
        return 'slide'
    elseif other.isEnemy then
        return 'slide'
    elseif other.isMinifier then
        return 'cross'  -- Love2D usa 'cross' en lugar de 'overlap'
    elseif other.isPlayer then
        return 'cross'  -- detectamos pero no bloqueamos
    else
        return 'cross'
    end
end
```

### 13.5 Sistema de rebotes

```lua
function CrewMember:processBounce(blockedX, blockedY)
    -- Decay
    if self.bounceCountDecayFrames > 0 then
        self.bounceCountDecayFrames = self.bounceCountDecayFrames - 1
    else
        self.recentBounceCount = 0
    end

    -- Solo si hay colisión Y no hay rebote activo
    if (blockedX or blockedY) and self.bounceFrames <= 0 then
        self.recentBounceCount = self.recentBounceCount + 1
        self.bounceCountDecayFrames = 30

        if self.recentBounceCount >= 2 then
            self:enterHiding()
            return
        end

        local playerToLeft = self.player.x < self.x
        local playerBelow  = self.player.y > self.y

        if blockedX and blockedY then
            self.bounceDirection = math.random() > 0.5
                and (playerBelow and 'up' or 'down')
                or  (playerToLeft and 'right' or 'left')
        elseif blockedX then
            self.bounceDirection = playerBelow and 'up' or 'down'
        elseif blockedY then
            self.bounceDirection = playerToLeft and 'right' or 'left'
        end

        self.bounceFrames = 20
    end
end
```

### 13.6 Hiding (collider removal en bump.lua)

```lua
function CrewMember:enterHiding()
    self.isHiding = true
    self.hidingTokensAccumulated = 0
    self.animState = "hide"
    self.hat:setVisible(false)

    -- Quitar del mundo de colisiones completamente
    bumpWorld:remove(self)
    self.inBumpWorld = false
end

function CrewMember:exitHiding()
    self.isHiding = false
    self.hidingTokensAccumulated = 0
    self.animState = "idle"
    self.hat:setVisible(true)

    -- Restaurar en el mundo de colisiones
    bumpWorld:add(self,
        self.x + self.collideOffsetX,
        self.y + self.collideOffsetY,
        self.collideW,
        self.collideH)
    self.inBumpWorld = true

    self.bounceDirection = nil
    self.bounceFrames = 0
end
```

### 13.7 Captura (`taken`)

```lua
function CrewMember:taken(player)
    -- Marcar en datos del nivel
    local roomData = levelsLDTK[self.room]
    for _, crewData in ipairs(roomData.entities.CrewMember) do
        if crewData.iid == self.iid then
            crewData.customFields.isTaken = true
            PlayerData.CrewMemberData.amountTaken += 1
            if self.crewId then
                PlayerData.CrewMemberData.idNumbers[self.crewId] = true
            end
            -- Restaurar plungerang (siempre, independiente del método de captura)
            if player then player.hasProjectile = true end
            break
        end
    end

    -- Remover de bump.lua
    if self.inBumpWorld then
        bumpWorld:remove(self)
    end

    -- Remover hat
    self.hat:destroy()

    -- Marcar para eliminación de la lista de entidades
    self.isDead = true
end
```

### 13.8 Colisión player → CM (en el player)

```lua
function Player:onCrewMemberCollision(crewMember)
    if PlayerData.isTiny then
        -- Modo tiny: trigger de diálogo
        self.currentTrigger = crewMember
        return  -- no capturar
    end

    -- Normal: capturar inmediatamente
    if PlayerData.CrewMemberData.amountTaken == 0 then
        dialogUI:addScreen("gotcha")  -- primera captura
    end
    crewMember:taken(self)
end
```

### 13.9 El Hat como sub-entidad separada

En Love2D, el hat es una entidad independiente que no participa en colisiones:

```lua
local Hat = {}
Hat.__index = Hat

function Hat.new(x, y, crewId)
    local self = setmetatable({}, Hat)
    self.x, self.y = x, y
    self.crewId = crewId
    self.visible = true
    -- Cargar frame correspondiente del spritesheet
    self.quad = hatQuads[crewId]  -- pre-construir quads para CM001-CM021
    return self
end

function Hat:moveTo(x, y)
    self.x, self.y = x, y - 15  -- siempre 15px arriba del CM
end

function Hat:setVisible(v)
    self.visible = v
end

function Hat:draw()
    if not self.visible then return end
    love.graphics.draw(hatSpritesheet, self.quad, self.x - 10, self.y - 8)
end
```

---

## 14. Checklist de Verificación para el Port

- [ ] El throttle es cada **2 frames** (no 3 como Brocorat)
- [ ] `recentBounceCount` se resetea si pasan **30 frames** sin rebote
- [ ] El hiding necesita **2 rebotes** seguidos (dentro de 30 frames)
- [ ] Para salir de hiding: player a **>80px** Y **≥3 tokens acumulados** (ambas condiciones)
- [ ] Durante hiding: `bumpWorld:remove` (no solo collideRect(0,0,0,0))
- [ ] `stunInfinite` es permanente — solo se cancela con `taken()`
- [ ] `taken()` siempre restaura `player.hasProjectile = true`
- [ ] El hat es un objeto separado, no hijo del sprite — mover manualmente
- [ ] En modo tiny: NO se captura, se asigna `currentTrigger`
- [ ] La captura ocurre en el callback del player, no del CM — el CM responde con `'cross'`/`'overlap'` al player
