LoseIndicator ={}
class('LoseIndicator').extends(NobleSprite)

function LoseIndicator:init(__x,__y)
	LoseIndicator.super.init(self, 'assets/images/ui/battle/playerIndicator',true)
	
	if bpm == nil then
		bpm = 6
	end
	local frameduration = bpm
	-- Mark: animation states
	self.animation:addState('player',1,1)
	self.animation.player.frameDuration = frameduration
	
	self:setZIndex(9)
	
	self.animation:setState('player')
	self:setSize(39, 31)
	self:add(__x,__y)
	
end
