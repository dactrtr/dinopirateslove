# NPC System

Static interactable entities (computers, terminals, phones) that give conditional dialog and optionally grant items or keys to the player.

> **See also:** [TRIGGER_SYSTEM.md](TRIGGER_SYSTEM.md) for the Trigger entity (which NPCs parallel). [DIALOG_SYSTEM.md](DIALOG_SYSTEM.md) for how `addScreen` and scripts work. [PROPS_AND_ITEMS.md](PROPS_AND_ITEMS.md) for the grants format.

---

## 1. How NPCs Work

NPCs are static sprites placed in LDtk. The player walks up to one and presses **A** to interact. The NPC evaluates its `conditionalScripts` list top-to-bottom and runs the first condition that matches, showing the corresponding dialog and optionally granting an item or key — but grants fire **only once**, even though the dialog is repeatable.

---

## 2. Creating an NPC in LDtk

### Step 1 — Define the entity type (first time only)

In LDtk, create a new entity type called **`NPC`** and add these custom fields:

| Field | Type | Default | Description |
|---|---|---|---|
| `type` | String | `"computer"` | Visual identifier used to load the sprite image |
| `conditionalScripts` | Array\<String\> | `[]` | Condition + dialog + optional grants (see format below) |
| `sourceFeed` | Int | `0` | Portrait index shown in the dialog video feed |
| `hasGranted` | Bool | `false` | Tracks if grants have been applied — **do not set manually, leave as false** |

### Step 2 — Place the NPC in a room

1. Select the `NPC` entity type in LDtk.
2. Place it at the desired position in the room.
3. Fill in `type` with the visual you want (e.g., `"computer"`, `"phone"`).
4. Fill in `conditionalScripts` (see Section 3).
5. Leave `hasGranted` as `false`.

---

## 3. conditionalScripts Format

Each entry in the array is a string with two or three colon-separated segments:

```
"condition:script"
"condition:script:grants"
```

The list is evaluated **top-to-bottom**. The first matching condition wins. The rest are ignored.

### condition

Uses the same syntax as Trigger conditions:

| Syntax | Example | Meaning |
|---|---|---|
| Boolean path | `items.hasLamp` | `PlayerData.items.hasLamp == true` |
| Negated boolean | `!isTiny` | `PlayerData.isTiny == false` |
| Numerical comparison | `mapPercent>50` | `PlayerData.mapPercent > 50` |
| Hardcoded true | `true` | Always matches — use as catch-all fallback (special case in evaluator, not a PlayerData path) |

Supported operators for numerical comparisons: `>` `<` `>=` `<=` `==` `!=`

### script

The `name` key of an entry in `assets/data/script.lua`. If not found, the dialog silently fails (same behavior as missing Trigger scripts — see DIALOG_SYSTEM.md).

### grants (optional)

What the NPC gives the player the **first time** this condition matches. Two formats:

| Format | Example | Effect |
|---|---|---|
| Key card | `key:2` | `PlayerData.keys[2] = true` |
| Inventory item | `hasBoots:true` | `PlayerData.items.hasBoots = true` |

Grants are applied only once (`hasGranted` flag). After that the dialog still plays but nothing is granted. Each condition supports **one grant** — to grant multiple things, chain conditions or use a script-driven approach.

---

## 4. Full Example

A terminal that gives the player a keycard only if they already have the lamp, and shows a different message otherwise:

```lua
-- In LDtk, conditionalScripts array:
[
  "items.hasLamp:terminal_authorized:key:3",
  "true:terminal_unauthorized"
]
```

In `assets/data/script.lua`:

```lua
{
    name = "terminal_authorized",
    dialog = {
        { video = 'radioHand', text = "terminal-auth-01" },
        { video = 'radioHand', text = "terminal-auth-02" }
    }
},
{
    name = "terminal_unauthorized",
    dialog = {
        { video = 'player', text = "terminal-denied" }
    }
}
```

In `source/en.strings`:

```
"terminal-auth-01" = "Access granted. Here is your keycard."
"terminal-auth-02" = "Use it to open the east corridor."
"terminal-denied"  = "Insufficient clearance."
```

First interaction (player has lamp): shows `terminal_authorized` dialog + gives key 3.  
All subsequent interactions (player has lamp): shows `terminal_authorized` dialog, no grant.  
Any interaction without lamp: shows `terminal_unauthorized`, no grant.

---

## 5. Adding New NPC Visuals

Add a static image at `assets/images/props/npc_<type>` (e.g., `npc_computer`, `npc_phone`). The NPC entity loads its sprite from this path using the `type` field.

---

## 6. Persistence

`hasGranted` is stored in the live `levelsLDTK` table and persisted automatically by `SaveSystem.save()` on room exit — same mechanism as `usedTrigger` on Triggers and `destroyed` on Props. No extra save system work needed.

---

## 7. Files Involved

| File | Role |
|---|---|
| `entities/props/npc.lua` | NPC entity class |
| `scenes/MazeScene.lua` | Import + spawn block |
| `entities/player/collisions.lua` | Sets NPC as `currentTrigger` on overlap |
| `assets/data/script.lua` | Dialog content for each NPC |
| `source/en.strings` | Localized text keys |
| `assets/images/props/npc_<type>` | Static sprite images |
