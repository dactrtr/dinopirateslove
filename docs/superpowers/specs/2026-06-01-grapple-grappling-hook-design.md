# Diseño: Grapple (plungerang cargado) — port LÖVE

Fecha: 2026-06-01

## Objetivo

Portar el gancho de agarre (grappling hook) del Playdate al port LÖVE como la
variante **cargada** del plungerang. Tap B sigue lanzando el plungerang normal
(boomerang); mantener B + crank carga el grapple, que al soltar dispara un gancho
que ignora todos los sprites y solo reacciona a tiles: si toca un `grapplePoint`
(valor 33) jala al jugador hasta ahí; si toca un muro o llega al máximo, vuelve
como boomerang.

## Decisiones (cerradas con el usuario)

- **Input de carga:** crank → stick derecho **y rueda del mouse** (convención del
  proyecto). Se reusa la abstracción `Input.getCrankDelta()` / `pendingCrankDelta`.
- **Modelo:** tap B = plunge; hold B + crank = grapple.
- **Gancho fiel:** ignora todos los sprites (no daña enemigos, no captura crew);
  solo reacciona a tiles (grapplePoint → jala, muro/máximo → rebota).
- **Alcance:** solo el sistema. Los `grapplePoint` en los niveles los autora el
  usuario después en LDtk (hoy el valor 33 aparece solo 1 vez; sin puntos, el
  grapple actúa como boomerang cargado, que es lo correcto).
- **Arquitectura:** enfoque A — módulo nuevo `entities/player/grapple.lua`,
  separado del `Projectile` (que usa bump). El gancho NO usa bump.
- **UI:** reusar `gameScene.interactionHUD` (port del UIHud del Playdate) con el
  estado `crankClock` ya existente.

## Valores de tuning (portados del Playdate `Config.Grapple`)

| Parámetro | Valor | Significado |
|---|---|---|
| holdDelay | 400 ms | tiempo manteniendo B antes de armar la carga (tap < esto = plunge) |
| minDistance | 64 px | distancia garantizada en cualquier release armado (~4 tiles) |
| maxDistance | 320 px | tope de distancia (~20 tiles) |
| pixelsPerDegree | 0.4 | grados de crank → distancia de lanzamiento |
| projectileSpeed | 8 px/frame | velocidad del gancho al salir/volver |
| pullSpeed | 8 px/frame | velocidad del jalón del jugador hacia el tile |
| cooldown | 500 ms | reservado; **no se aplica** (inerte, igual que en el Playdate) |
| ropeWidth | 2 px | grosor de la cuerda |

Otros: `Config.Tiles.IntGrid.grapplePoint = 33`, `Config.Player.feetOffsetY = 12`,
`Config.Player.movementTokensPerAction = 5`.

## Componentes

### 1. Config (`assets/data/Config.lua`)
- `Config.Tiles.IntGrid.grapplePoint = 33`; agregar `33` a `Config.Tiles.walkable`.
- `Config.Grapple = { holdDelay, minDistance, maxDistance, pixelsPerDegree, projectileSpeed, pullSpeed, cooldown, ropeWidth }` (`cooldown` se incluye como valor reservado/inerte, fiel al Playdate).
- `Config.Player.feetOffsetY = 12` y `Config.Player.movementTokensPerAction = 5`
  (verificar si ya existen equivalentes antes de duplicar).

### 2. Detección de tile grapplePoint (`utilities.lua`)
- Agregar `utilities.GRAPPLE_POINT_ID` (o reusar `Config.Tiles.IntGrid.grapplePoint`).
- El gancho muestrea el tile bajo su centro con `utilities.getTileUnderPlayer`
  (misma función que usan slime/hole). Necesita un helper de "walkable" para
  decidir rebote: tile walkable (incluye 0,2,3,4,32,33) = sigue; no walkable = muro = rebota.

### 3. `entities/player/grapple.lua` (nuevo)
Módulo que define el gancho y las funciones de carga/jalón del Player.

**`GrappleHook`** (middleclass, sin bump):
- `initialize(player, direction, maxDistance, world?)`: posición inicial en el
  jugador (`y + feetOffsetY` aprox.), animación spin con `projectile-table-24-24.png`.
- `update(dt)`:
  - Si `returning`: vuela hacia el jugador a `projectileSpeed`; al llegar
    (dist ≤ speed) → `remove()` + `player:onGrappleFinished()`.
  - Si no: avanza en la dirección a `projectileSpeed`. Muestrea tile bajo el centro:
    - `== grapplePoint` → centro del tile `(cx, cy)`; `player:startGrapplePull(cx, cy - feetOffsetY)`; `remove()` + `onGrappleFinished()`.
    - no walkable (muro/fuera de mapa) → `returning = true`.
    - acumula `distanceTravelled`; si `≥ maxDistance` → `returning = true`.
- `draw()`: dibuja la animación + la **cuerda** (`love.graphics.line` del pie del
  jugador al centro del gancho, grosor `ropeWidth`, color oscuro). Espacio del
  canvas 400×240 (sin transformaciones de cámara).

**Métodos del Player (en el mismo archivo o en init.lua):**
- `beginGrappleCharge()`: guards (gaming, tiene plunger+canPlungerang, no tiny,
  `hasProjectile`, no `isInDarkness`, no `isOnHole()`, no charging/plunging/pulling/grappling).
  Entra en `isGrappleCharging`, resetea `grappleCrankAccum`, marca `grappleChargeStart`.
- `addGrappleCrankDelta(delta)`: si charging y delta > 0, acumula en `grappleCrankAccum`.
- `endGrappleCharge()`: si no charging, return. Sale de charging, oculta HUD.
  - Si `dir` idle/nil → cancela (no dispara).
  - Si `isOnHole()` → cancela.
  - Si se mantuvo ≥ holdDelay (armado) → dispara grapple:
    `distance = clamp(minDistance + grappleCrankAccum * pixelsPerDegree, min, max)`;
    crea `grappleHook`; `isGrappling = true`; `distributeMovementTokens(movementTokensPerAction)`; `idle()`.
  - Si fue tap (< holdDelay) → `plunge()` (comportamiento actual, sin cambios).
- `onGrappleFinished()`: limpia `isGrappling`, `grappleHook`.
- `startGrapplePull(tx, ty)`: fija target, `isGrapplePulling = true`.
- `updateGrapplePull(dt)`: desliza hacia el target a `pullSpeed`; anima dirección;
  al llegar → `moveTo(target)`, `idle()`, `isGrapplePulling = false`.

### 4. Estados nuevos del Player (constructor `init.lua`)
`isGrappleCharging`, `isGrappling`, `isGrapplePulling` (bool, false),
`grappleCrankAccum` (0), `grappleChargeStart` (0/nil), `grappleHook` (nil).

La cuerda NO es una entidad separada: el `GrappleHook:draw()` dibuja la línea del
pie del jugador al gancho. No hay `grappleRope`.

### 5. Integración en `Player:update`
- Igual que el slide: si `isGrapplePulling` → `updateGrapplePull(dt)` y **saltar**
  el input/movimiento normal (input bloqueado durante el jalón).
- Mientras `isGrappling` → actualizar el `grappleHook` (o se actualiza desde gameScene).

### 6. Input (`gameScene` + `main.lua` + `InputBindings.lua`)
- **B-down** (teclado `keypressed` + gamepad `gamepadpressed`): si gaming y el
  jugador puede grapplear → `player:beginGrappleCharge()` (en vez del
  `handleActionButton` inmediato). Preservar las otras ramas de B (cancelar
  minifier, cerrar menú).
- **Crank → grapple** (dos fuentes ya cableadas, enrutar por estado):
  - Stick: en `gameScene.gamepadInput`, donde hoy se consume `Input.getCrankDelta()`
    y va a `handleCrankInput` (minifier), agregar branch: si `isGrappleCharging` →
    `grapple.addCrankDelta(player, cd)`.
  - Rueda: en `gameScene.wheelmoved(x, y)` (ya existe), branch: si `isGrappleCharging`
    → `grapple.addCrankDelta(player, y * math.rad(30))`; si no → `handleCrankInput(y)` (sin cambios).
- **B-up:** teclado vía nuevo `gameScene.keyreleased(key)` (sceneManager ya lo
  enruta); gamepad vía polling `Input.wasReleased("BButton")` en `gamepadInput`
  (agregar `Input.wasReleased` a `InputBindings.lua`). Ambos → `grapple.endCharge(player)`.

Nota: la rueda del mouse YA está cableada (`love.wheelmoved` → `sceneManager.wheelmoved`
→ `gameScene.wheelmoved`, main.lua:368). NO hay que agregar handlers en main.lua ni
tocar `pendingCrankDelta`. El crank (stick + rueda) devuelve/usa radianes; la
distancia del grapple convierte con `math.deg()` antes de aplicar `pixelsPerDegree`.

### 7. UI de carga (`gameScene`)
- Reusar `gameScene.interactionHUD`. Cuando `player.isGrappleCharging` y armado →
  `interactionHUD:setState("crankClock")` + `setVisible(true)`, con prioridad sobre
  el chequeo de triggers (mismo patrón que `readyToShrink`, gameScene ~1474-1476).
- Al terminar la carga → ocultar / dejar que el chequeo de triggers retome.

### 8. Render del gancho (`Player:draw`)
- Mientras `grappleHook` exista, dibujarlo (gancho + cuerda) desde `Player:draw`,
  igual que hoy se dibuja `self.projectile` (init.lua ~337). No requiere tocar el
  draw de gameScene.

## Manejo de errores / casos borde
- Sala sin grapplePoints → el gancho vuelve como boomerang (correcto).
- Soltar B en idle (sin dirección) → cancela carga, no dispara.
- Caer en hole o entrar en diálogo durante la carga → cancela (`isOnHole()` / guards).
- El jalón bloquea input hasta llegar; no se puede cancelar a media trayectoria.
- En oscuridad → no hay grapple (es habilidad de sala iluminada); B se comporta como hoy.
- Sin plunger / sin skill / tiny → no hay carga; B mantiene comportamiento actual.

## Pruebas
No hay framework de tests (LÖVE interpreta Lua). Verificación manual:
1. Tap B → lanza plungerang (boomerang) como hoy.
2. Mantener B + girar stick derecho / rueda del mouse → aparece `crankClock`; al
   soltar, el gancho sale en la dirección encarada, rebota en muros y vuelve.
3. Con un `grapplePoint` (tile 33) de prueba en una sala → el gancho lo toca y jala
   al jugador hasta el centro del tile.
4. Validar sintaxis con `luac -p` en los archivos tocados.

## Archivos afectados
- `assets/data/Config.lua` (Config.Grapple, grapplePoint, walkable, feetOffsetY, movementTokensPerAction)
- `entities/player/grapple.lua` (NUEVO)
- `entities/player/init.lua` (estados, integración en update, require del módulo)
- `entities/player/plunge.lua` (sin cambios, se sigue llamando en el tap)
- `utilities.lua` (helper grapplePoint / walkable si hace falta)
- `scenes/gameScene.lua` (input B down/up, routing de crank por estado, UI crankClock, keyreleased)
- `assets/data/InputBindings.lua` (agregar `Input.wasReleased(action)`)

## Fuera de alcance
- Lado oscuro (lámpara / dark reveal cargado) — solo el grapple (sala iluminada).
- Autoría de `grapplePoint` en los niveles (lo hace el usuario).

Nota: el `cooldown` SÍ se incluye en `Config.Grapple` como valor reservado/inerte
(fiel al Playdate, donde está definido pero ningún código lo aplica). No se cablea
ningún cooldown funcional.
