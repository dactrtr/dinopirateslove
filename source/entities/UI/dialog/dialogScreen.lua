-- entities/UI/dialog/dialogScreen.lua
local Class = require 'libraries/middleclass'
local VideoFeed = require 'entities/UI/dialog/videoFeed'
local ImageScreen = require 'entities/UI/dialog/imageScreen'

local DialogScreen = Class('DialogScreen')

function DialogScreen:initialize()
    self.videoFeed = VideoFeed()
    self.imageScreen = ImageScreen()
    self.dialogBoxImage = love.graphics.newImage('assets/images/ui/dialog/dialogbox.png')
    
    -- Create a smaller font for dialogs
    self.font = love.graphics.newFont(16) -- Smaller than the default 20
    
    self.currentScript = nil
    self.currentIndex = 0
    self.active = false
    
    -- UI Layout (Targeting 400x240 virtual resolution)
    -- Matching original Playdate code:
    -- dialogBG:moveTo(0, 138)
    self.boxX = 0
    self.boxY = 138
    
    -- text position: moveTo(16, 165)
    self.textX = 16 -- Shifted right to make room for video
    self.textY = 160
    self.textWidth = 240
    
    -- video position: 
    -- User code says self:add(x,y) with 400,240? 
    -- Likely NobleSprite centering logic. We'll place it in the box.
    self.videoX = 280
    self.videoY = 142
end

function DialogScreen:addScreen(scriptName)
    if not _G.script then
        printDebug("⚠️ Error: Global 'script' table not found.")
        return
    end
    
    -- Don't restart if already playing this script
    if self.active and self.currentScript and self.currentScript.name == scriptName then
        return
    end
    
    local targetScript = nil
    for _, s in ipairs(_G.script) do 
        if s.name == scriptName then
            targetScript = s
            break
        end
    end
    
    if not targetScript then
        printDebug("⚠️ Warning: Script '" .. tostring(scriptName) .. "' not found.")
        return
    end
    
    self.currentScript = targetScript
    self.currentIndex = 0
    self.active = true
    PlayerData.isTalking = true
    
    self:nextDialog()
end

function DialogScreen:nextDialog()
    if not self.active then return end
    
    self.currentIndex = self.currentIndex + 1
    
    if self.currentIndex > #self.currentScript.dialog then
        self:removeAll()
        return
    end
    
    local entry = self.currentScript.dialog[self.currentIndex]
    
    -- Update components
    if entry.video then
        self.videoFeed:setState(entry.video)
    end
    
    if entry.screen then
        self.imageScreen:setImage(entry.screen)
    else
        self.imageScreen:clear()
    end
    
    -- Localization
    if Graphics and Graphics.getLocalizedText then
        self.currentText = Graphics.getLocalizedText(entry.text)
    else
        self.currentText = entry.text
    end
end

function DialogScreen:removeAll()
    self.active = false
    self.currentScript = nil
    self.currentIndex = 0
    self.imageScreen:clear()
    PlayerData.isTalking = false
    -- Set PlayerData.isGaming if it exists
    if PlayerData.isGaming ~= nil then
        PlayerData.isGaming = true
    end
end

function DialogScreen:update(dt)
    if not self.active then return end
    self.videoFeed:update(dt)
end

function DialogScreen:draw()
    if not self.active then return end
    
    -- Draw ImageScreen (background / cutscene still)
    -- imageScreen:moveTo(50, 4)
    self.imageScreen.x = 200 -- Keep it centered for Love2D unless specific pos needed
    self.imageScreen.y = 70
    self.imageScreen:draw()
    
    -- Draw Dialog Box
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.dialogBoxImage, self.boxX, self.boxY)
    
    -- Draw Video Feed (Portrait)
    self.videoFeed:draw(self.videoX, self.videoY)
    
    -- Draw Text
    -- User requested black color and smaller size
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.196, 0.184, 0.161, 1)
    love.graphics.printf(self.currentText, self.textX, self.textY, self.textWidth)
    
    -- Reset to default font/color for other components
    love.graphics.setColor(1, 1, 1, 1)
    if font then love.graphics.setFont(font) end
end

return DialogScreen
