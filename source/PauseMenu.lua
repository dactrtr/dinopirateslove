-- PauseMenu.lua - Reusable pause menu component
local PauseMenu = {}
PauseMenu.__index = PauseMenu

function PauseMenu.new(buttons)
	local self = setmetatable({}, PauseMenu)
	
	self.visible = false
	self.selectedButton = 1
	self.buttons = buttons or {
		{text = "Resume", action = "resume"},
		{text = "Main Menu", action = "mainmenu"},
		{text = "Quit Game", action = "quit"}
	}
	
	-- Input state tracking for gamepad
	self.lastInputs = {
		up = false,
		down = false,
		a = false,
		b = false,
		start = false
	}
	
	return self
end

function PauseMenu:show()
	self.visible = true
	self.selectedButton = 1
end

function PauseMenu:hide()
	self.visible = false
end

function PauseMenu:toggle()
	if self.visible then
		self:hide()
	else
		self:show()
	end
end

function PauseMenu:isVisible()
	return self.visible
end

function PauseMenu:update(dt)
	-- Menu doesn't need continuous updates, but this is here for future use
end

function PauseMenu:draw()
	if not self.visible then return end
	
	-- Semi-transparent overlay
	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
	
	-- Menu dimensions
	local menuWidth = 220
	local menuHeight = 120
	local menuX = (VIRTUAL_WIDTH - menuWidth) / 2
	local menuY = (VIRTUAL_HEIGHT - menuHeight) / 2
	
	-- Menu background with border
	love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
	love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
	love.graphics.setColor(0.6, 0.6, 0.6, 1)
	love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
	
	-- Menu title
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("PAUSED", menuX, menuY + 15, menuWidth, "center")
	
	-- Menu buttons
	for i, button in ipairs(self.buttons) do
		local buttonY = menuY + 45 + (i - 1) * 25
		
		-- Highlight selected button
		if i == self.selectedButton then
			love.graphics.setColor(0.3, 0.5, 0.8, 0.4)
			love.graphics.rectangle("fill", menuX + 8, buttonY - 3, menuWidth - 16, 21)
			love.graphics.setColor(1, 1, 0.2) -- Yellow text for selected
		else
			love.graphics.setColor(0.8, 0.8, 0.8) -- Light gray for unselected
		end
		
		love.graphics.printf(button.text, menuX + 15, buttonY, menuWidth - 30, "center")
	end
end

function PauseMenu:keypressed(key)
	if not self.visible then return false end
	
	if key == "up" then
		self:navigateUp()
		return true
	elseif key == "down" then
		self:navigateDown()
		return true
	elseif key == "return" or key == "space" then
		return self:selectButton()
	elseif key == "escape" then
		self:hide()
		return true
	end
	
	return false -- Key not handled
end

function PauseMenu:gamepadInput(input)
	if not self.visible then 
		-- Check for menu open with start button when menu is closed
		if input.start and not self.lastInputs.start then
			self:show()
		end
		self.lastInputs.start = input.start
		return false 
	end
	
	-- Handle menu navigation with gamepad
	if input.up and not self.lastInputs.up then
		self:navigateUp()
	elseif input.down and not self.lastInputs.down then
		self:navigateDown()
	elseif input.a and not self.lastInputs.a then
		return self:selectButton()
	elseif input.b and not self.lastInputs.b then
		self:hide()
		return true
	end
	
	-- Store previous input states
	self.lastInputs.up = input.up
	self.lastInputs.down = input.down
	self.lastInputs.a = input.a
	self.lastInputs.b = input.b
	self.lastInputs.start = input.start
	
	return true -- Input handled
end

function PauseMenu:navigateUp()
	self.selectedButton = self.selectedButton - 1
	if self.selectedButton < 1 then
		self.selectedButton = #self.buttons
	end
end

function PauseMenu:navigateDown()
	self.selectedButton = self.selectedButton + 1
	if self.selectedButton > #self.buttons then
		self.selectedButton = 1
	end
end

function PauseMenu:selectButton()
	local action = self.buttons[self.selectedButton].action
	self:hide() -- Hide menu when button is selected
	return action -- Return the action to be handled by the scene
end

function PauseMenu:setButtons(buttons)
	self.buttons = buttons
	self.selectedButton = 1
end

function PauseMenu:addButton(text, action)
	table.insert(self.buttons, {text = text, action = action})
end

return PauseMenu