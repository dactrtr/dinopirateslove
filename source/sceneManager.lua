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
	fromCanvas = nil, -- Snapshot of fromScene
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
	
	-- Capture current state to canvas
	if not transition.fromCanvas then
		transition.fromCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH or 400, VIRTUAL_HEIGHT or 240)
	end
	
	love.graphics.push("all")
	love.graphics.setCanvas(transition.fromCanvas)
	love.graphics.clear()
	love.graphics.setColor(1, 1, 1, 1)
	if transition.fromScene and transition.fromScene.draw then
		transition.fromScene.draw()
	end
	love.graphics.setCanvas()
	love.graphics.pop()
	
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
		
		
		-- Mid-transition swap (at 50% or start for animated)
		local swapThreshold = 0.5
		if transition.type == "animated" then swapThreshold = 0.1 end -- Swap early for animated
		
		if not transition.swapped and transition.timer / transition.duration >= swapThreshold then
			transition.swapped = true
			
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
		end
		
		if transition.timer >= transition.duration then
			-- Transition complete
			transition.active = false
			transition.timer = 0
			transition.swapped = false
			
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
		if progress <= 0.5 then
			-- First half: Fade from old scene to black
			local fadeProgress = progress * 2 -- 0 to 1
			
			-- Draw from canvas (captured old state)
			if transition.fromCanvas then
				love.graphics.setColor(1, 1, 1, 1)
				love.graphics.draw(transition.fromCanvas, 0, 0)
			end
			
			-- Fade to black overlay
			love.graphics.setColor(0, 0, 0, fadeProgress)
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
		else
			-- Second half: Fade from black to new scene
			local fadeInProgress = (progress - 0.5) * 2 -- 0 to 1
			
			-- Draw to scene (new state)
			if transition.toScene and transition.toScene.draw then
				love.graphics.setColor(1, 1, 1, 1)
				transition.toScene.draw()
			end
			
			-- Fade from black overlay
			love.graphics.setColor(0, 0, 0, 1 - fadeInProgress)
			love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
		end
		
	elseif transition.type == "slide" then
		local offset = progress * love.graphics.getWidth()
		
		-- Draw from canvas sliding out
		love.graphics.push()
		love.graphics.translate(-offset, 0)
		if transition.fromCanvas then
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.draw(transition.fromCanvas, 0, 0)
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
		-- Draw from canvas (captured old state)
		if transition.fromCanvas then
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.draw(transition.fromCanvas, 0, 0)
		end

		-- Draw to scene if swapped
		if transition.swapped then
			if transition.toScene and transition.toScene.draw then
				transition.toScene.draw()
			end
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

function sceneManager.gamepadInput(input)
	if transition.active then return end
	if currentScene and currentScene.gamepadInput then
		currentScene.gamepadInput(input)
	end
end

function sceneManager.gamepadpressed(button)
	if transition.active then return end
	if currentScene and currentScene.gamepadpressed then
		currentScene.gamepadpressed(button)
	end
end

function sceneManager.gamepadreleased(button)
	if transition.active then return end
	if currentScene and currentScene.gamepadreleased then
		currentScene.gamepadreleased(button)
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

function sceneManager.keyreleased(key)
	if transition.active then return end
	if currentScene and currentScene.keyreleased then
		currentScene.keyreleased(key)
	end
end

function sceneManager.getCurrentSceneName()
	return currentSceneName
end

function sceneManager.isTransitioning()
	return transition.active
end

return sceneManager