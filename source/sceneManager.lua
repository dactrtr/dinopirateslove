local sceneManager = {}
local anim8 = require 'libraries/anim8'

-- Scene management
local scenes = {}
local currentScene = nil
local currentSceneName = ""

-- Transition system
local transition = {
	active = false,
	duration = 0.5,
	timer = 0,
	type = "fade", -- "fade", "slide", "animated"
	fromScene = nil,
	toScene = nil,
	fromSceneName = "",
	toSceneName = "",
	-- Animated transition data
	animation = nil,
	spritesheet = nil,
	animationName = nil -- "transitionFall", etc.
}

-- Transition animations cache
local transitionAnimations = {}

function sceneManager.init()
	scenes = {}
	currentScene = nil
	currentSceneName = ""
	
	-- Load transition animations
	sceneManager.loadTransitionAnimations()
end

function sceneManager.loadTransitionAnimations()
	-- Load transitionFall
	local fallSheet = love.graphics.newImage('assets/images/screens/transitions/transitionFallEnter-table-400-240.png')
	local fallGrid = anim8.newGrid(400, 240, fallSheet:getWidth(), fallSheet:getHeight())
	
	transitionAnimations.transitionFall = {
		spritesheet = fallSheet,
		animation = anim8.newAnimation(fallGrid('1-10', 1), 0.05) -- 10 frames, 0.05s each = 0.5s total
	}
	
	-- Add more transitions here as needed
end

function sceneManager.registerScene(name, scene)
	scenes[name] = scene
end

function sceneManager.setCurrentScene(name)
	if scenes[name] then
		-- Handle exit lifecycle for previous scene
		if currentScene and currentScene.exit then
			currentScene.exit()
		end

		currentScene = scenes[name]
		currentSceneName = name

		-- Handle enter lifecycle
		if currentScene and currentScene.enter then
			currentScene.enter()
		end
	end
end

function sceneManager.getScene(name)
	return scenes[name]
end

function sceneManager.startTransition(fromSceneName, toSceneName, transitionType, animationName)
	if not scenes[toSceneName] then
		printDebug("Warning: Scene '" .. toSceneName .. "' not found!")
		return
	end
	
	transition.active = true
	transition.timer = 0
	transition.fromScene = scenes[fromSceneName]
	transition.toScene = scenes[toSceneName]
	transition.fromSceneName = fromSceneName
	transition.toSceneName = toSceneName
	transition.type = transitionType or "fade"
	
	-- Setup animated transition if specified
	if transitionType == "animated" and animationName then
		local transData = transitionAnimations[animationName]
		if transData then
			transition.animation = transData.animation:clone()
			transition.spritesheet = transData.spritesheet
			transition.animationName = animationName
			transition.animation:gotoFrame(1)
			transition.duration = 0.5 -- Match animation duration
		else
			printDebug("Warning: Animation '" .. animationName .. "' not found, using fade")
			transition.type = "fade"
		end
	end
end

function sceneManager.update(dt)
	if transition.active then
		transition.timer = transition.timer + dt
		
		-- Update animated transition
		if transition.type == "animated" and transition.animation then
			transition.animation:update(dt)
		end
		
		if transition.timer >= transition.duration then
			-- Transition complete
			transition.active = false
			transition.timer = 0
			
			-- Handle exit lifecycle
			if currentScene and currentScene.exit then
				currentScene.exit()
			end
			
			currentScene = transition.toScene
			currentSceneName = transition.toSceneName
			
			-- Handle enter lifecycle
			if currentScene and currentScene.enter then
				currentScene.enter()
			end
			
			transition.fromScene = nil
			transition.toScene = nil
			transition.fromSceneName = ""
			transition.toSceneName = ""
			transition.animation = nil
			transition.spritesheet = nil
			transition.animationName = nil
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
	
	elseif transition.type == "animated" then
		-- Draw to scene first (background)
		if transition.toScene and transition.toScene.draw then
			transition.toScene.draw()
		end
		
		-- Draw animated transition overlay
		-- Use premultiplied alpha blend mode to treat white as opaque
		if transition.animation and transition.spritesheet then
			love.graphics.setBlendMode("alpha", "premultiplied")
			love.graphics.setColor(1, 1, 1, 1)
			transition.animation:draw(transition.spritesheet, 0, 0)
			-- Reset to default blend mode
			love.graphics.setBlendMode("alpha", "alphamultiply")
		end
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

function sceneManager.wheelmoved(x, y)
	if transition.active then
		return
	end
	
	if currentScene and currentScene.wheelmoved then
		currentScene.wheelmoved(x, y)
	end
end

function sceneManager.getCurrentSceneName()
	return currentSceneName
end

function sceneManager.isTransitioning()
	return transition.active
end

return sceneManager