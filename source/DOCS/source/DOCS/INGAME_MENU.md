# In-Game Menu (inGameMenu)

This document describes the player's equipment menu: opening and closing, item selection, the equipment system, `activeItem` routing, and the distinction between pause and equipping.

---

## Files Involved

| File | Class | Description |
|---|---|---|
| `entities/UI/inGameMenu.lua` | `inGameMenu` | Main menu container |
| `entities/UI/itemMenu.lua` | `itemMenu` | Individual skill/item icon |
| `entities/UI/skillInfo.lua` | `skillInfo` | Active skill banner panel |

---

## `inGameMenu` — Structure

Extends `Graphics.sprite`. Instantiated in `MazeScene:enter()`.

### Visual Components

| Component | Description | Position |
|---|---|---|
| `shadow` (400×240) | Semi-transparent background covering the screen | (200, 120) |
| `menuSprite` | Menu frame image (`assets/images/ui/menu/ingame-menu`) | (200, 120) centered |
| `lampItem` | Lamp item icon | (320, 64) when visible |
| `bootItem` | Boots icon | (288, 128) when visible |
| `plungerItem` | Plunger icon | (256, 128) when visible |
| `equippedInfoPanel` | Banner for the currently selected skill | (220, 180) when an item is active |
| `hatSprites` | Array of captured crew member hat sprites | Grid starting at (43, 108) |

### Z-Index

| Element | Z-Index |
|---|---|
| `inGameMenu` (shadow) | `ZIndex.menu` (2100) |
| `menuSprite` | `ZIndex.menu + 2` (2102) |
| `itemMenu`, `skillInfo` | `ZIndex.menu + 3` (2103) |
| `equippedInfoPanel` | `ZIndex.menu + 4` (2104) |
| Hat sprites | `ZIndex.menu + 9` (2109) |

---

## Opening the Menu

### Condition

```lua
function inGameMenu:displayMenu()
    if not PlayerData.items.hasDWatch then return end  -- requires D-Watch
    PlayerData.isGaming = false
    PlayerData.isEquiping = true
    self:drawMapOnMenu()
    if PlayerData.CrewMemberData.amountTaken > 0 then
        self:drawCrewHats()
    end
end
```

**Mandatory requirement:** `PlayerData.items.hasDWatch == true`. Without the D-Watch, `displayMenu()` returns without doing anything.

### Who Calls It

`MazeScene` calls it from `AButtonHeld` (A held for 1 second).

### State Changes

```
PlayerData.isGaming   → false   (disables gameplay, movement input, abilities)
PlayerData.isEquiping → true    (activates menu input)
```

---

## Closing the Menu

```lua
function inGameMenu:closeMenu()
    shadow:clear(Graphics.kColorClear)
    lampItem:remove()
    bootItem:remove()
    plungerItem:remove()
    equippedInfoPanel:remove()
    menuSprite:remove()
    -- Remove hat sprites
    for _, hatSprite in ipairs(self.hatSprites or {}) do
        hatSprite:remove()
    end
    self.hatSprites = nil
end
```

### Who Calls It

`MazeScene` calls it from `BButtonDown` when `isEquiping == true`.

### State Changes After Closing

```
PlayerData.isGaming   → true    (reactivates gameplay)
PlayerData.isEquiping → false
```

---

## Distinction: Pause vs. Equipping

The game **has no real pause system**. Opening the equipment menu simulates a pause by setting `isGaming = false`, which:

- Stops player movement (movement input checks `isGaming`).
- Stops abilities (B checks `isGaming` to use abilities).
- Stops the enemy turn (`distributeMovementTokens` only runs when there is active input).

However, `update()` keeps running — the menu draws its components every frame. There is no literal engine freeze.

`SaveSystem.save()` is called in `scene:pause()` (Playdate system menu) and in `scene:finish()` — **not** when opening the equipment menu.

---

## Skill Navigation

### `inGameMenu:getActiveSkillsList()`

Dynamically builds the list of available skills based on the player's **skills**, not item possession:

```lua
function inGameMenu:getActiveSkillsList()
    local skills = {}
    if PlayerData.skills.canFlash      then table.insert(skills, 1) end  -- Lamp/Flash
    if PlayerData.skills.canDash       then table.insert(skills, 2) end  -- Boot/Dash
    if PlayerData.skills.canPlungerang then table.insert(skills, 3) end  -- Plunger/Plunge
    return skills
end
```

**Skill IDs:**
- `1` = Flash (Lamp)
- `2` = Dash (Boots)
- `3` = Plungerang (Plunger)

### `inGameMenu:prevItem()` / `inGameMenu:nextItem()`

Cycle `PlayerData.activeItem` within the active list with wraparound:

```lua
-- nextItem:
currentIndex = currentIndex + 1
if currentIndex > #activeSkills then currentIndex = 1 end
PlayerData.activeItem = activeSkills[currentIndex]

-- prevItem:
currentIndex = currentIndex - 1
if currentIndex < 1 then currentIndex = #activeSkills end
PlayerData.activeItem = activeSkills[currentIndex]
```

If there are no active skills, `PlayerData.activeItem` is set to `0`.

### `inGameMenu:selectItem()`

Confirms the selection. In the current code it only calls `printDebug`. The actual selection already happened when navigating with `prevItem`/`nextItem` — `activeItem` is updated in real time.

---

## `activeItem` Routing

`PlayerData.activeItem` is the active skill number. It is used in multiple systems:

| Value | Skill | Gameplay Use (B button) |
|---|---|---|
| `0` | None | `useAbility()` does nothing |
| `1` | Flash | `player:lightBurst()` |
| `2` | Dash | `player:dash()` |
| `3` | Plungerang | `player:plunge()` |

The menu validates that `activeItem` is always a value within `getActiveSkillsList()`. If it is not, it resets it to the first available skill.

---

## `itemMenu` — Individual Item Icon

Extends `NobleSprite`. Image: `assets/images/ui/menu/menuitems`.

### Animation States

| State | Frame | Condition |
|---|---|---|
| `lamp` | 5 | Lamp not selected |
| `lampSelected` | 6 | `activeItem == 1` |
| `boot` | 3 | Boots not selected |
| `bootSelected` | 4 | `activeItem == 2` |
| `plunger` | 1 | Plunger not selected |
| `plungerSelected` | 2 | `activeItem == 3` |

`itemMenu:show(x, y)` adds it to the scene at the given position. `itemMenu:remove()` removes it.

---

## `skillInfo` — Skill Information Panel

Extends `NobleSprite`. Image: `assets/images/ui/menu/skillinfo`. Size: 145×42 px.

### Animation States

| State | Frame | Skill Displayed |
|---|---|---|
| `plunder` | 1 | Plungerang |
| `dash` | 2 | Dash |
| `flash` | 3 | Flash/Lamp |

When created with `__item = 'equipped'`, `update()` reads `PlayerData.activeItem` and changes state automatically to always show the active skill.

`skillInfo:show(x, y)` adds it to the scene.

---

## Crew Hats (`drawCrewHats`)

When opening the menu, if `CrewMemberData.amountTaken > 0`, hat sprites are created for each captured crew member.

### Layout

```
Start: x=43, y=108
Horizontal spacing: 20 px
Vertical spacing: 20 px
Maximum per row: 7 hats
```

Calculates the position of each hat by its grid index:
```lua
local row = math.floor(slotIndex / maxHatsPerRow)
local col = slotIndex % maxHatsPerRow
hatSprite:moveTo(hatX + col*20, hatY + row*20)
```

Hats are removed in `closeMenu()`.

---

## Game Map in the Menu

On opening, `inGameMenu:drawMapOnMenu()` calls `MapDrawer.drawMap(menuImage)` to draw the explored map directly onto the menu image.

---

## Notes for Porting to Love2D

### Structure in Love2D

```lua
-- InGameMenu.lua
InGameMenu = {}

function InGameMenu:open()
    if not PlayerData.items.hasDWatch then return end
    PlayerData.isGaming = false
    PlayerData.isEquiping = true
end

function InGameMenu:close()
    PlayerData.isGaming = true
    PlayerData.isEquiping = false
end

function InGameMenu:draw()
    if not PlayerData.isEquiping then return end
    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 400, 240)
    -- Menu frame
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.menuImage, 200, 120, 0, 1, 1,
        self.menuImage:getWidth()/2, self.menuImage:getHeight()/2)
    -- Available skills
    self:drawSkills()
end
```

### Active Skill Cycling

```lua
function InGameMenu:getActiveSkills()
    local skills = {}
    if PlayerData.skills.canFlash      then table.insert(skills, {id=1, name="Flash"}) end
    if PlayerData.skills.canDash       then table.insert(skills, {id=2, name="Dash"}) end
    if PlayerData.skills.canPlungerang then table.insert(skills, {id=3, name="Plungerang"}) end
    return skills
end

function InGameMenu:nextItem()
    local skills = self:getActiveSkills()
    if #skills == 0 then return end
    local idx = 1
    for i, s in ipairs(skills) do
        if s.id == PlayerData.activeItem then idx = i; break end
    end
    idx = (idx % #skills) + 1
    PlayerData.activeItem = skills[idx].id
end
```

### Key Difference: Input Held

In Playdate, `AButtonHeld` is a Noble Engine callback that fires after 1 second. In Love2D, it must be detected manually with a timer in `love.update(dt)`.
