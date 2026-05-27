TestScene = {}
class("TestScene").extends(NobleScene)
local scene = TestScene
--TestScene.backgroundColor = Graphics.kColorWhite

function scene:init()
	scene.super.init(self)
    
end


function scene:enter()
	scene.super.enter(self)
	sequence = Sequence.new():from(0):to(100, 1.5, Ease.outBounce)
	
    
end

function scene:start()
	scene.super.start(self)


end

function scene:drawBackground()
	scene.super.drawBackground(self)
    local background = Graphics.image.new('assets/test/testbg.png')
	background:draw(0, 0)
end

function scene:update()
	scene.super.update(self)
   
end

function scene:exit()
	scene.super.exit(self)

	Noble.Input.setCrankIndicatorStatus(false)
	sequence = Sequence.new():from(100):to(240, 0.25, Ease.inSine)
	sequence:start();

end

function scene:finish()
	scene.super.finish(self)
end


scene.inputHandler = {

    -- A button
    --
    AButtonDown = function()			-- Runs once when button is pressed.
        -- Your code here
    end,
    AButtonHold = function()			-- Runs every frame while the player is holding button down.
        -- Your code here
    end,
    AButtonHeld = function()			-- Runs after button is held for 1 second.
        -- Your code here
    end,
    AButtonUp = function()				-- Runs once when button is released.
        -- Your code here
    end,

    -- B button
    --
    BButtonDown = function()
        -- Your code here
    end,
    BButtonHeld = function()
        -- Your code here
    end,
    BButtonHold = function()
        -- Your code here
    end,
    BButtonUp = function()
    end,

    -- D-pad left
    --
    leftButtonDown = function()
        -- Your code here
    end,
    leftButtonHold = function()
        -- Your code here
    end,
    leftButtonUp = function()
    end,

    -- D-pad right
    --
    rightButtonDown = function()
        -- Your code here
    end,
    rightButtonHold = function()
        -- Your code here
    end,
    rightButtonUp = function()
    end,

    -- D-pad up
    --
    upButtonDown = function()
        -- Your code here
    end,
    upButtonHold = function()
        -- Your code here
    end,
    upButtonUp = function()
    end,

    -- D-pad down
    --
    downButtonDown = function()
        -- Your code here
    end,
    downButtonHold = function()
        -- Your code here
    end,
    downButtonUp = function()
    end,

    -- Crank
    --
    cranked = function(change, acceleratedChange)	-- Runs when the crank is rotated. See Playdate SDK documentation for details.
        -- Your code here
    end,
    crankDocked = function()						-- Runs once when when crank is docked.
        -- Your code here
    end,
    crankUndocked = function()						-- Runs once when when crank is undocked.
        -- Your code here
    end
}

