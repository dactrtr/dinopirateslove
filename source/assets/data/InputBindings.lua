-- source/assets/data/InputBindings.lua
-- ─────────────────────────────────────────────────────────────
-- INPUT BINDINGS
-- Edita este archivo para remapear cualquier control del juego.
-- ─────────────────────────────────────────────────────────────

local Input = {}

-- ── GAMEPLAY ─────────────────────────────────────────────────
-- AButton: confirmar, avanzar diálogo. Hold 0.5s → abre menú equipo.
Input.AButton = {"z", "return", "space"}
-- BButton: activar item equipado en juego / cancelar en menús.
Input.BButton = {"x"}

-- ── NAVIGATION ───────────────────────────────────────────────
Input.up    = {"w", "up"}
Input.down  = {"s", "down"}
Input.left  = {"a", "left"}
Input.right = {"d", "right"}

-- ── SYSTEM ───────────────────────────────────────────────────
Input.pause  = {"escape"}
Input.resize = {"e"}   -- placeholder crank de Playdate

-- Evento sintético despachado por el hold timer de main.lua.
-- No asignes esta tecla manualmente.
Input.menuOpen = {"__menuOpen__"}

-- ── DEV / WINDOW ─────────────────────────────────────────────
Input.toggleCRT  = {"q"}
Input.fullscreen = {"f"}
Input.res1 = {"1"}
Input.res2 = {"2"}
Input.res3 = {"3"}

-- ── DANCE SCENE ──────────────────────────────────────────────
-- Mapeo de teclas físicas a botones de ritmo usados en DanceScene.
Input.danceKeys = {
    ["return"] = "aButton",  ["space"]  = "aButton",
    ["lshift"] = "bButton",  ["rshift"] = "bButton",
    ["left"]   = "leftButton", ["right"] = "rightButton",
    ["up"]     = "upButton",   ["down"]  = "downButton",
}

-- ── HELPERS ──────────────────────────────────────────────────

--- Devuelve true si `key` coincide con algún binding de Input[action].
function Input.is(key, action)
    local binds = Input[action]
    if not binds then return false end
    for _, k in ipairs(binds) do
        if key == k then return true end
    end
    return false
end

--- Devuelve true si alguna tecla de Input[action] está presionada.
function Input.isDown(action)
    local binds = Input[action]
    if not binds then return false end
    for _, k in ipairs(binds) do
        if love.keyboard.isDown(k) then return true end
    end
    return false
end

return Input
