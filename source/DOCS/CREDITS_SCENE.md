# CreditsScene

**File**: `scenes/CreditsScene.lua`  
**Asset**: `assets/credits/credits-tangara.png`

A simple scrolling credits scene. Reached from TitleScene via the "Credits" menu item. Auto-returns to TitleScene when all content has scrolled off screen.

---

## Layout & Constants

| Constant | Value | Purpose |
|---|---|---|
| `SCROLL_SPEED` | 1 px/frame | Normal scroll rate |
| `SCROLL_SPEED_FAST` | 3 px/frame | Scroll rate while A is held |
| `LINE_HEIGHT` | 20 px | Height reserved for a text item |
| `ITEM_SPACING` | 16 px | Vertical gap between consecutive items |
| `START_OFFSET` | 260 px | Initial Y of the first item (just below screen bottom at 240) |

Background color is `Graphics.kColorBlack`. Text is drawn in white (`kDrawModeFillWhite`). Images use `kDrawModeCopy`.

---

## Credits Table

The content is defined as a flat Lua table of items inside the file. Three item types are supported:

| Type | Fields | Effect |
|---|---|---|
| `"text"` | `value` (string) | Draws text centered at x=200 |
| `"image"` | `path` (string) | Draws image centered horizontally |
| `"space"` | `height` (number) | Empty vertical gap, no drawing |

To change the credits content, edit the `credits` table at the top of `CreditsScene.lua`. Order is top-to-bottom as they scroll up.

---

## Lifecycle

### `enter()`
1. Resets all local state (`scrollY = 0`, `isDone = false`).
2. **Preloads all images** — iterates the `credits` table and loads every `"image"` item into `loadedImages[path]` so `drawBackground()` never reads from disk during gameplay.
3. **Computes `totalHeight`** — sums `itemHeight()` for every item plus `ITEM_SPACING` between them. Used to know when scrolling is complete.

### `update()`
- Advances `scrollY` by `SCROLL_SPEED` (or `SCROLL_SPEED_FAST` if A is held).
- When `scrollY >= START_OFFSET + totalHeight` (all content past the top edge), sets `isDone = true` and calls `Noble.transition(TitleScene)`. The `isDone` guard prevents the transition from firing on subsequent frames.

### `drawBackground()`
- Iterates the `credits` table. Starting Y is `START_OFFSET - scrollY`.
- Skips items fully outside the screen (`y + h < 0` or `y > 240`) for efficiency.
- Advances Y by `itemHeight(item) + ITEM_SPACING` after each item.

### `exit()`
- Clears `loadedImages` to free memory.

### `finish()`
- Resets `Graphics.setImageDrawMode` to `kDrawModeCopy` (cleanup for next scene).

---

## Input

| Input | Effect |
|---|---|
| Hold A | Speeds up scrolling (3× normal) |
| B | Immediately returns to TitleScene |
| Auto | Returns to TitleScene when scroll completes |
