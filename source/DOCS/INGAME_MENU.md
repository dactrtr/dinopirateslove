# In-Game Equipment Menu

The in-game menu (`inGameMenu.lua`) is a specialized UI overlay that allows the player to pause the game, view the map, see collected crew member hats, and equip active skills (Flash/Lamp, Dash/Boots, Plungerang).

---

## 🎮 Playdate Implementation

### 1. Structure
Path: `entities/UI/inGameMenu.lua`

The menu is an extension of `Graphics.sprite`.
- **Z-Index:** Set very high (`ZIndex.menu` and above) to draw over everything else.
- **Components:**
  - A background image (`menuImage`) — a `Graphics.image` object that also receives the map drawing.
  - A map overlay drawn **directly onto `menuImage`** via `MapDrawer.drawMap(menuImage)` — not on-screen directly.
  - Icons for available skills (Lamp/Flash, Boots/Dash, Plungerang), managed via `itemMenu` components.
  - Grid of collected crew member hats from spritesheet `assets/images/props/hats` (CM001–CM021, indices 1–21).

### 2. hasDWatch Gate

> [!IMPORTANT]
> **The menu only opens if `PlayerData.items.hasDWatch == true`.**
> The very first line of `displayMenu()` checks:
> ```lua
> function inGameMenu:displayMenu()
>     if not PlayerData.items.hasDWatch then return end
>     -- ...
> end
> ```
> If the player hasn't collected the DWatch, `displayMenu()` returns immediately. Never show the menu without this check.

### 3. State Management
The menu state is tightly coupled with two global variables in `_G.PlayerData`:
- `PlayerData.isGaming`: When `false`, standard game mechanics and inputs are disabled.
- `PlayerData.isEquiping`: When `true`, it flags that the equipment menu is active and hijacking input.

### 4. Usage & Input Handling
Located primarily in `scenes/MazeScene.lua`.

- **Opening the menu (A Button Held):**
  Holding the **A Button** for ~1 second (`AButtonHeld`) triggers `inGameEquip:displayMenu()`. This sets `isGaming = false` and `isEquiping = true`.

- **Navigating (D-pad Left/Right):**
  When `isEquiping` is `true`, pressing Left/Right calls `inGameEquip:prevItem()` and `inGameEquip:nextItem()`. These cycle through only the **unlocked skills** by building an `activeSkills` list first — locked skills are skipped entirely.

- **Skill IDs:**
  | ID | Skill | Requires |
  |---|---|---|
  | 1 | Flash (Lightburst) | `skills.canFlash` |
  | 2 | Dash | `skills.canDash` |
  | 3 | Plungerang | `skills.canPlungerang` |

- **Selecting (A Button):**
  Pressing the **A Button** (`AButtonDown`) while the menu is open invokes `inGameEquip:selectItem()`.

- **Closing the menu (B Button):**
  Pressing **B** sets `isGaming = true`, `isEquiping = false`, and invokes `inGameEquip:closeMenu()`.

### 5. Map Drawing
The minimap is drawn into `menuImage` (a `Graphics.image` object), not directly to the screen:
```lua
function inGameMenu:drawMapOnMenu()
    MapDrawer.drawMap(menuImage)  -- draws into the image buffer
end
```
In Love2D, use a `Canvas` for this equivalent.

### 6. Crew Hats
Hat sprites are loaded from `assets/images/props/hats` as an imagetable. The menu iterates CM001–CM021 (indices 1–21), checks `PlayerData.CrewMemberData.idNumbers[crewId] == true`, and creates a sprite for each captured crew member's hat.

---

## 🔁 Love2D Implementation Example

### Example: Basic Structure in Love2D

```lua
-- InGameMenu.lua
InGameMenu = {}

function InGameMenu:load()
    self.menuImage = love.graphics.newCanvas(400, 240)
    -- Draw map into canvas using MapDrawer equivalent
    self:drawMapOnCanvas()

    self.items = {
        { id = 1, name = "Flash",     skillKey = "canFlash"     },
        { id = 2, name = "Dash",      skillKey = "canDash"      },
        { id = 3, name = "Plungerang",skillKey = "canPlungerang" }
    }
end

function InGameMenu:drawMapOnCanvas()
    love.graphics.setCanvas(self.menuImage)
    -- ... draw minimap tiles here (see LEVEL_LOADING.md)
    love.graphics.setCanvas()
end

function InGameMenu:getActiveSkills()
    local active = {}
    for _, item in ipairs(self.items) do
        if PlayerData.skills[item.skillKey] then
            table.insert(active, item)
        end
    end
    return active
end

function InGameMenu:open()
    if not PlayerData.items.hasDWatch then return end  -- CRITICAL: gate on hasDWatch
    PlayerData.isGaming = false
    PlayerData.isEquiping = true
    self:drawMapOnCanvas()
end

function InGameMenu:draw()
    if not PlayerData.isEquiping then return end
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 400, 240)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.menuImage, 0, 0)

    local activeSkills = self:getActiveSkills()
    for i, skill in ipairs(activeSkills) do
        if PlayerData.activeItem == skill.id then
            love.graphics.setColor(1, 1, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.print(skill.name, 350, 200 + (i * 30))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function InGameMenu:nextItem()
    local skills = self:getActiveSkills()
    if #skills == 0 then return end
    local currentIndex = 1
    for i, skill in ipairs(skills) do
        if skill.id == PlayerData.activeItem then currentIndex = i; break end
    end
    currentIndex = currentIndex % #skills + 1
    PlayerData.activeItem = skills[currentIndex].id
end

function InGameMenu:prevItem()
    local skills = self:getActiveSkills()
    if #skills == 0 then return end
    local currentIndex = 1
    for i, skill in ipairs(skills) do
        if skill.id == PlayerData.activeItem then currentIndex = i; break end
    end
    currentIndex = currentIndex - 1
    if currentIndex < 1 then currentIndex = #skills end
    PlayerData.activeItem = skills[currentIndex].id
end
```

### Key Differences

| Aspect | Playdate | Love2D |
|---|---|---|
| Map target | `Graphics.image` (menuImage) | `love.graphics.Canvas` |
| Rendering | `Graphics.sprite` system | Explicit `love.draw()` calls |
| Hold detection | `AButtonHeld` callback | Accumulate time in `love.update(dt)` |
| Sub-sprites (hats) | `Graphics.sprite` instances | Objects in a draw list |

### Hold A to Open (Love2D)
```lua
-- In love.update(dt):
if love.keyboard.isDown("return") then
    self.holdTimer = (self.holdTimer or 0) + dt
    if self.holdTimer >= 1.0 then  -- ~1 second hold
        InGameMenu:open()
        self.holdTimer = 0
    end
else
    self.holdTimer = 0
end
```
