-- scenes/CreditsScene.lua
-- Scrolling end credits, shown when a run is completed (full crew recruited →
-- final room, see gameScene endgame). Hold A to fast-forward; press B/Back/Esc to
-- skip; auto-returns to the title once everything has scrolled off the top.
-- Ported from the Playdate CreditsScene to the LÖVE scene pattern (plain table).

local sceneManager = require "sceneManager"

local creditsScene = {}

-- Scroll speeds in px/second (the Playdate used 1/3 px per frame at 50fps).
local SCROLL_SPEED      = 18
local SCROLL_SPEED_FAST = 54
-- Layout (virtual 400x240 space)
local LINE_HEIGHT  = 14
local ITEM_SPACING = 10
local START_OFFSET = 240   -- first item starts just below the screen bottom

-- Edit this table to change the credits content. Item types:
--   { type = "text",  value = "string" }       — white text, centered
--   { type = "image", path = "assets/..." }     — image centered horizontally
--   { type = "space", height = N }              — empty vertical gap
local credits = {
    { type = "space", height = 20 },
    { type = "text",  value = "DinoPirates from Inner Space" },
    { type = "text",  value = "Brocolation" },
    { type = "space", height = 30 },
    { type = "text",  value = "A game by" },
    { type = "space", height = 8 },
    { type = "text",  value = "Sebastian Andres Guillermo Zuniga Rivas" },
    { type = "text",  value = "A.K.A" },
    { type = "text",  value = "dactrtr.rocks" },
    { type = "space", height = 30 },
    { type = "text",  value = "Music" },
    { type = "space", height = 8 },
    { type = "text",  value = "Alan Munoz" },
    { type = "space", height = 30 },
    { type = "text",  value = "Cursor pack and Input Prompts Pixel 1-Bit by:" },
    { type = "image", path = "assets/credits/credits-kenney.png" },
    { type = "space", height = 30 },
    { type = "text",  value = "Special thanks to:" },
    { type = "space", height = 8 },
    { type = "text",  value = "Jacob Wilschrey - Dev help" },
    { type = "text",  value = "Christian Padilla - Game test" },
    { type = "space", height = 8 },
    { type = "text",  value = "This game wouldnt been possible" },
    { type = "text",  value = "without the support and love of" },
    { type = "text",  value = "Jenna Heo" },
    { type = "space", height = 40 },
    { type = "text",  value = "Thanks for playing!" },
    { type = "space", height = 80 },
    { type = "image", path = "assets/credits/credits-tangara.png" },
    { type = "space", height = 60 },
}

-- Module-local state (reset in enter())
local scrollY      = 0
local totalHeight  = 0
local loadedImages = {}
local isDone       = false
local font         = nil

local function itemHeight(item)
    if item.type == "text" then
        return LINE_HEIGHT
    elseif item.type == "image" then
        local img = loadedImages[item.path]
        return img and img:getHeight() or 0
    elseif item.type == "space" then
        return item.height
    end
    return 0
end

function creditsScene.load()
    font = love.graphics.newFont(12)
    loadedImages = {}
    for _, item in ipairs(credits) do
        if item.type == "image" and not loadedImages[item.path] then
            local ok, img = pcall(love.graphics.newImage, item.path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                loadedImages[item.path] = img
            else
                printDebug("⚠️ Credits: image not found: " .. item.path)
            end
        end
    end
end

function creditsScene.enter()
    scrollY = 0
    isDone  = false
    PlayerData.isGaming = false

    totalHeight = 0
    for i, item in ipairs(credits) do
        totalHeight = totalHeight + itemHeight(item)
        if i < #credits then totalHeight = totalHeight + ITEM_SPACING end
    end
end

local function toTitle()
    if isDone then return end
    isDone = true
    sceneManager.startTransition("credits", "title", "fade")
end

function creditsScene.update(dt)
    -- Hold A to fast-forward (polled, so no key-up edge handling needed).
    local fast  = Input and Input.isDown and Input.isDown("AButton")
    local speed = fast and SCROLL_SPEED_FAST or SCROLL_SPEED
    scrollY = scrollY + speed * dt

    -- Everything has scrolled past the top → back to title.
    if scrollY >= START_OFFSET + totalHeight then
        toTitle()
    end
end

function creditsScene.draw()
    love.graphics.clear(0, 0, 0, 1)
    local prevFont = love.graphics.getFont()
    if font then love.graphics.setFont(font) end

    local y = START_OFFSET - scrollY
    for _, item in ipairs(credits) do
        local h = itemHeight(item)
        if y + h >= 0 and y <= VIRTUAL_HEIGHT then
            if item.type == "text" then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(item.value, 0, math.floor(y), VIRTUAL_WIDTH, "center")
            elseif item.type == "image" then
                local img = loadedImages[item.path]
                if img then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(img, math.floor(VIRTUAL_WIDTH / 2 - img:getWidth() / 2), math.floor(y))
                end
            end
        end
        y = y + h + ITEM_SPACING
    end

    love.graphics.setColor(1, 1, 1, 1)
    if prevFont then love.graphics.setFont(prevFont) end
end

-- Skip to title with B / pause (Esc).
function creditsScene.keypressed(key)
    if Input.is(key, "BButton") or Input.is(key, "pause") then
        toTitle()
    end
end

-- Gamepad: B or Back skips to title (A fast-forward is polled in update).
function creditsScene.gamepadInput(input)
    if input and (input.b or input.back) then
        toTitle()
    end
end

return creditsScene
