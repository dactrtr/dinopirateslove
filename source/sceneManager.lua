local sceneManager = {}

-- Scene management
local scenes = {}
local currentScene = nil
local currentSceneName = ""

-- Transition system
local transition = {
	active = false,
	duration = 0.5,
	timer = 0,
	type = "dissolve", -- "fade", "slide", "dissolve"
	fromScene = nil,
	toScene = nil,
	fromSceneName = "",
	toSceneName = ""
}

function sceneManager.init()
	scenes = {}
	currentScene = nil
	currentSceneName = ""
end

function sceneManager.registerScene(name, scene)
	scenes[name] = scene
end

function sceneManager.setCurrentScene(name)
	if scenes[name] then
		currentScene = scenes[name]
		currentSceneName = name
	end
end

function sceneManager.startTransition(fromSceneName, toSceneName, transitionType)
	if not scenes[toSceneName] then
		print("Warning: Scene '" .. toSceneName .. "' not found!")
		return
	end
	
	transition.active = true
	transition.timer = 0
	transition.fromScene = scenes[fromSceneName]
	transition.toScene = scenes[toSceneName]
	transition.fromSceneName = fromSceneName
	transition.toSceneName = toSceneName
	transition.type = transitionType or "fade"
end

function sceneManager.update(dt)
	if transition.active then
		transition.timer = transition.timer + dt
		if transition.timer >= transition.duration then
			-- Transition complete
			transition.active = false
			transition.timer = 0
			currentScene = transition.toScene
			currentSceneName = transition.toSceneName
			transition.fromScene = nil
			transition.toScene = nil
			transition.fromSceneName = ""
			transition.toSceneName = ""
		end
	else
		-- Update current scene
		if currentScene and currentScene.update then
			currentScene.update(dt)
		end
	end
end

function sceneManager.draw()
	if transition.active then
		drawTransition()
	else
		-- Draw current scene
		if currentScene and currentScene.draw then
			currentScene.draw()
		end
	end
end

function drawTransition()
	local progress = transition.timer / transition.duration
	
	if transition.type == "fade" then
		-- Draw from scene
		if transition.fromScene and transition.fromScene.draw then
			transition.fromScene.draw()
		end
		
		-- Fade overlay
		love.graphics.setColor(0, 0, 0, progress)
		love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
		
		-- Draw to scene if we're past halfway
		if progress > 0.5 then
			local fadeIn = (progress - 0.5) * 2  -- 0 to 1 for second half
			love.graphics.setColor(0, 0, 0, 1 - fadeIn)
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
			
			if transition.toScene and transition.toScene.draw then
				transition.toScene.draw()
			end
		end
		
	elseif transition.type == "slide" then
		local offset = progress * love.graphics.getWidth()
		
		-- Draw from scene sliding out
		love.graphics.push()
		love.graphics.translate(-offset, 0)
		if transition.fromScene and transition.fromScene.draw then
			transition.fromScene.draw()
		end
		love.graphics.pop()
		
		-- Draw to scene sliding in
		love.graphics.push()
		love.graphics.translate(love.graphics.getWidth() - offset, 0)
		if transition.toScene and transition.toScene.draw then
			transition.toScene.draw()
		end
		love.graphics.pop()
	end
	
	love.graphics.setColor(1, 1, 1)  -- Reset color
end

function sceneManager.keypressed(key)
	if transition.active then
		return  -- Ignore input during transitions
	end
	
	-- Pass input to current scene
	if currentScene and currentScene.keypressed then
		currentScene.keypressed(key)
	end
end

function sceneManager.getCurrentSceneName()
	return currentSceneName
end

function sceneManager.isTransitioning()
	return transition.active
end

return sceneManager