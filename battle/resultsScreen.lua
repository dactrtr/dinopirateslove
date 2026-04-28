ResultsScreen ={}
class('ResultsScreen').extends(NobleSprite)

function ResultsScreen:init()
	ResultsScreen.super.init(self, 'assets/images/ui/battle/resultsdance',true)
	
	if bpm == nil then
		bpm = 6
	end
	local frameduration = bpm
	-- Mark: animation states
	self.animation:addState('empty',1,1)
	self.animation.empty.frameDuration = frameduration
	self.animation:addState('win',2,2)
	self.animation.win.frameDuration = frameduration
	self.animation:addState('lose',3,3)
	self.animation.lose.frameDuration = frameduration
	self.animation:addState('ready', 4,4)
	self.animation.ready.frameDuration = frameduration
	
	self:setZIndex(10)
	
	self.animation:setState('empty')
	self:setSize(400, 240)
	self:add(200,120)
	
end

function ResultsScreen:win()
	self.animation:setState('win')
end
function ResultsScreen:lose()
	self.animation:setState('lose')
end
function ResultsScreen:loadingScreen()
	self.animation:setState('ready')
end
function ResultsScreen:empty()
	self.animation:setState('empty')
end