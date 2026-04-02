# HUD System Documentation

The HUD (Heads-Up Display) provides real-time information about the player's status, including battery life, health, and sanity. It is anchored to the player and drawn on top of the game world.

---

## 🖥️ Main Component: `playerHud`
Path: `entities/UI/playerHud.lua`

The `playerHud` is a `NobleSprite` that follows the player and coordinates several sub-indicators.

- **Positioning**: Moves to `(player.x, player.y - 36)` normally, or `(player.x, player.y - 22)` when `PlayerData.isTiny == true`.
- **Visibility**: The entire HUD (background, battery, health) is only visible when `PlayerData.items.hasDWatch` is true. The HUD is hidden without the D-Watch regardless of lamp or boot ownership.
- **Sanity States**: The HUD background image changes based on `PlayerData.sanity`.
    - `sanity100`: > 80 (States 1,1)
    - `sanity80`: > 60 (States 3,4)
    - `sanity60`: > 40 (States 5,6)
    - `sanity40`: > 20 (States 7,9)
    - `sanity20`: > 0 (States 10,11)
    - `sanity0`: 0 (States 12,13)

---

## ❤️ Health Representation: `HealthIndicator`
Path: `entities/UI/healthIndicator.lua`

The Health Indicator represents the player's `healthPoints` (default **3**).

- **Logic**: Draws one filled black square per health point. The `xPositions` array supports up to 10 HP positions. With the default of 3, only 3 squares fill.
- **Coordinates**: The squares are drawn at specific pixel offsets to align with the `UIHud` image:
    - `xPositions = {4, 5, 10, 11, 16, 17, 22, 23, 28, 29}`
    - `yPos = 8`
- **Update**: Redraws whenever `PlayerData.healthPoints` changes.

---

## 🔋 Battery Indicator: `Battery`
Path: `entities/UI/battery.lua`

The Battery Indicator shows the charge level in the canister.

- **Visibility**: The battery image updates only when `hasLamp or hasBoots` is true. Overall HUD visibility is controlled by `playerHud` (requires `hasDWatch`).
- **Logic**: Draws a black bar where the width is calculated as `(battery * 27) / 100`.
- **Position**: Offset slightly from the main HUD `(tx, ty - 3)`.

---

## 🗝️ Key Indicator: `keyHud`
Path: `entities/UI/keyHud.lua`

`keyHud` is a standalone sprite class. **It is imported by `playerHud.lua` but never instantiated there.** It exists as an independent component and is not wired into the `playerHud` hierarchy.

## 🧠 Sanity HUD: `sanityHud`
Path: `entities/UI/sanityHud.lua`

Similarly, `sanityHud` is imported by `playerHud.lua` but **not instantiated** — only `batteryIndicator` and `healthIndicator` are created by `playerHud`. Sanity is reflected via the background image state changes in `playerHud` itself (the `sanity100`, `sanity80`, etc. states).

---

## 🛠️ Z-Index Management
The HUD and its children use a layered Z-Index to ensure correct rendering order:
- `ZIndex.hud` (2000): Main HUD background.
- `ZIndex.hud + 1`: Battery Indicator.
- `ZIndex.hud + 2`: Health Indicator.

> [!TIP]
> All indicators read directly from the global `PlayerData` (or `_G.PlayerData`) for synchronization.

---

## 🎮 Love2D Porting Notes

### 1. HUD as a Canvas Layer
In Love2D, draw the HUD last in `love.draw` using a fixed screen-space canvas:
```lua
function love.draw()
    -- Draw world
    drawWorld()
    -- Draw HUD on top (screen-space, no camera transform)
    love.graphics.origin()
    if PlayerData.items.hasDWatch then
        HUD:draw(player.x, player.y)
    end
end
```

### 2. Follow Player Position
```lua
function HUD:draw(playerX, playerY)
    local yOffset = PlayerData.isTiny and -22 or -36
    local hudX, hudY = playerX, playerY + yOffset
    love.graphics.draw(self.bgImage, hudX, hudY)
    self.battery:draw(hudX, hudY)
    self.health:draw(hudX, hudY)
end
```

### 3. Sanity Background States
Map `PlayerData.sanity` thresholds to image variants:
```lua
local function getSanityState(sanity)
    if sanity > 80 then return "sanity100"
    elseif sanity > 60 then return "sanity80"
    elseif sanity > 40 then return "sanity60"
    elseif sanity > 20 then return "sanity40"
    elseif sanity > 0  then return "sanity20"
    else return "sanity0" end
end
```

### 4. Health Bar
Draw one square per HP point using `love.graphics.rectangle`:
```lua
local xPositions = {4,5,10,11,16,17,22,23,28,29}
for i = 1, PlayerData.healthPoints do
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", hudX + xPositions[i], hudY + 8, 1, 3)
end
```

---

## 🎒 In-Game Menu Overlay
Path: `entities/UI/inGameMenu.lua`

The in-game menu is a separate UI component that overlays the screen to display equipment (Lamp, Boots, Plungerang), a map, and collected crew member hats. 
For deep details on how the menu operates and examples for implementing it in Love2D, refer to the [In-Game Menu Documentation](file:///Users/dactrtr-mini/Documents/GitHub/Dinopirates/source/DOCS/INGAME_MENU.md).
