local sceneManager = require "sceneManager"
local config = require "config"
local titleScene = {
	currentOption = 1,
	options = { "Start Game", "Quit" },
	backgroundImage = nil
}

function titleScene.load()
	titleScene.backgroundImage = love.graphics.newImage("assets/screens/titlescreen.png")
end

function titleScene.update(dt)
	-- Title scene logic (if needed)
end



function titleScene.draw()
	-- Draw background image
	love.graphics.draw(titleScene.backgroundImage, 0, 0)

	-- Menu options positioning using virtual resolution
	local screenWidth = config.VIRTUAL_WIDTH
	local screenHeight = config.VIRTUAL_HEIGHT
	local optionHeight = 30
	local totalOptionsHeight = #titleScene.options * optionHeight
	local startY = screenHeight - totalOptionsHeight - 20  -- 20px margin from bottom

	for i, option in ipairs(titleScene.options) do
		local y = startY + (i - 1) * optionHeight
		if i == titleScene.currentOption then
			love.graphics.setColor(1, 1, 0) -- Yellow
		else
			love.graphics.setColor(1, 1, 1) -- White
		end
		love.graphics.printf(option, 0, y, screenWidth, "center")
	end

	love.graphics.setColor(1, 1, 1) -- Reset to white
end

function titleScene.keypressed(key)
	if key == "down" then
		titleScene.currentOption = titleScene.currentOption + 1
		if titleScene.currentOption > #titleScene.options then 
			titleScene.currentOption = 1 
		end
	elseif key == "up" then
		titleScene.currentOption = titleScene.currentOption - 1
		if titleScene.currentOption < 1 then 
			titleScene.currentOption = #titleScene.options 
		end
	elseif key == "return" or key == "kpenter" then
		if titleScene.currentOption == 1 then
			-- Start transition to game
			sceneManager.startTransition("title", "game", "fade")
		elseif titleScene.currentOption == 2 then
			love.event.quit()
		end
	end
end

return titleScene