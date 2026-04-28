ButtonCover ={}
class('ButtonCover').extends(NobleSprite)

function ButtonCover:init()
	ButtonCover.super.init(self, 'assets/images/ui/battle/buttoncover',true)
	
	if bpm == nil then
		bpm = 6
	end
	local frameduration = bpm
	-- Mark: animation states
	self.animation:addState('cover',1,1)
	self.animation.cover.frameDuration = frameduration
	
	self:setZIndex(9)
	
	self.animation:setState('cover')
	self:setSize(78, 58)
	self:add(361, 32)
	
end
