HitZone ={}
class('HitZone').extends(NobleSprite)

function HitZone:init(x,y,bpm)
	HitZone.super.init(self, 'assets/images/ui/battle/hitzone',true)
	
	if bpm == nil then
		bpm = 6
	end
	local frameduration = bpm
	-- Mark: animation states
	self.animation:addState('checker',1,8)
	self.animation.checker.frameDuration = frameduration
	
	self.animation:setState('checker')
	self.range = 100
	self:setSize(10, 40)
	self:setZIndex(5)
	self:setCollideRect(0, 0, 10, 40)
	self:add(x, y)
	
end

function HitZone:update()
	
end