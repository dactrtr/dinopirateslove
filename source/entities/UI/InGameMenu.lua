local InGameMenu = {
    menuImage = nil,
    itemsImage = nil,
    itemQuads = {},
    font = nil,
    items = {
        { id = 1, name = "Lamp", hasItem = "hasLamp" },
        { id = 2, name = "Boots", hasItem = "hasBoots" },
        { id = 3, name = "Plungerang", hasItem = "hasPlunger" }
    }
}

function InGameMenu:load()
    self.menuImage = love.graphics.newImage("assets/images/ui/menu/ingame-menu.png")
    self.itemsImage = love.graphics.newImage("assets/images/ui/menu/menuitems-table-32-32.png")
    self.font = love.graphics.newFont(16)
    
    -- Create quads for items (assuming 3 items in a row in the 32x32 spritesheet)
    for i = 1, 3 do
        self.itemQuads[i] = love.graphics.newQuad((i-1)*32, 0, 32, 32, self.itemsImage:getWidth(), self.itemsImage:getHeight())
    end
end

function InGameMenu:getActiveSkills()
    local active = {}
    for _, item in ipairs(self.items) do
        if PlayerData.items[item.hasItem] then
            table.insert(active, item)
        end
    end
    return active
end

function InGameMenu:draw()
    if not PlayerData.isEquiping then return end

    -- Draw Semi-transparent background
    love.graphics.setColor(0.196, 0.184, 0.161, 0.7)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    -- Draw Menu Box
    love.graphics.setColor(1, 1, 1, 1)
    local cx, cy = VIRTUAL_WIDTH/2, VIRTUAL_HEIGHT/2
    love.graphics.draw(self.menuImage, cx, cy, 0, 1, 1, self.menuImage:getWidth()/2, self.menuImage:getHeight()/2)
    
    -- Draw Skills/Items
    local activeSkills = self:getActiveSkills()
    
    local startY = cy - 40
    local totalWidth = #activeSkills * 40
    local startX = cx - (totalWidth / 2) + 20

    for i, skill in ipairs(activeSkills) do
        local x = startX + (i-1)*40 - 16
        
        -- Draw selection box
        if PlayerData.activeItem == skill.id then
            love.graphics.setColor(1, 1, 0, 1) -- Highlight selected item in yellow
            love.graphics.rectangle("line", x - 2, startY - 2, 36, 36)
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        if self.itemQuads[skill.id] then
            love.graphics.draw(self.itemsImage, self.itemQuads[skill.id], x, startY)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw instruction
    love.graphics.setFont(self.font)
    love.graphics.printf("Select Item", cx - 100, cy + 30, 200, "center")
end

function InGameMenu:nextItem()
    local skills = self:getActiveSkills()
    if #skills == 0 then return end
    
    local currentIndex = 1
    for i, skill in ipairs(skills) do
        if skill.id == PlayerData.activeItem then
            currentIndex = i
            break
        end
    end
    
    currentIndex = currentIndex + 1
    if currentIndex > #skills then currentIndex = 1 end
    PlayerData.activeItem = skills[currentIndex].id
end

function InGameMenu:prevItem()
    local skills = self:getActiveSkills()
    if #skills == 0 then return end
    
    local currentIndex = 1
    for i, skill in ipairs(skills) do
        if skill.id == PlayerData.activeItem then
            currentIndex = i
            break
        end
    end
    
    currentIndex = currentIndex - 1
    if currentIndex < 1 then currentIndex = #skills end
    PlayerData.activeItem = skills[currentIndex].id
end

function InGameMenu:keypressed(key)
    if Input.is(key, "right") then
        self:nextItem()
        return true
    elseif Input.is(key, "left") then
        self:prevItem()
        return true
    end
    return false
end

function InGameMenu:gamepadInput(input)
    if input.dpright or input.leftx and input.leftx > 0.5 then
        self:nextItem()
        return true
    elseif input.dpleft or input.leftx and input.leftx < -0.5 then
        self:prevItem()
        return true
    end
    return false
end

return InGameMenu
