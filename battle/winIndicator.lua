WinIndicator ={}
class('WinIndicator').extends(NobleSprite)

function WinIndicator:init(__x,__y)
	WinIndicator.super.init(self, 'assets/images/ui/battle/enemyIndicator',true)
	
	if bpm == nil then
		bpm = 6
	end
	local frameduration = bpm
	-- Mark: animation states
	self.animation:addState('enemy',1,1)
	self.animation.enemy.frameDuration = frameduration
	
	self:setZIndex(9)
	
	self.animation:setState('enemy')
	self:setSize(39, 31)
	self:add(__x,__y)
	
end
