local sceneManager = require "sceneManager"

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
	-- Draw background image scaled to fit screen
	-- Draw background image at original resolution
	love.graphics.draw(titleScene.backgroundImage, 0, 0)
	
	-- Draw menu options
	for i, option in ipairs(titleScene.options) do
		if i == titleScene.currentOption then
			love.graphics.setColor(1, 1, 0)  -- Yellow for selected option
		else
			love.graphics.setColor(1, 1, 1)  -- White for unselected options
		end
		love.graphics.printf(option, 0, 100 + i * 30, love.graphics.getWidth(), "center")
	end
	love.graphics.setColor(1, 1, 1)  -- Reset color to white
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