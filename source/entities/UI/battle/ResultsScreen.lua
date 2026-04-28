-- entities/UI/battle/ResultsScreen.lua
ResultsScreen = {}
ResultsScreen.__index = ResultsScreen

local FRAME = { playing=1, loading=2, win=3, lose=4 }

function ResultsScreen.new()
    local self = setmetatable({ state = "loading" }, ResultsScreen)
    self.image = love.graphics.newImage('assets/images/ui/battle/resultsdance-table-400-240.png')
    local iw = self.image:getWidth()
    local fw, fh = 400, 240
    self.quads = {}
    local nFrames = math.floor(iw / fw)
    for i = 1, nFrames do
        self.quads[i] = love.graphics.newQuad((i-1)*fw, 0, fw, fh, iw, fh)
    end
    return self
end

function ResultsScreen:empty()         self.state = "playing" end
function ResultsScreen:win()           if self.state ~= "win"  then self.state = "win"  end end
function ResultsScreen:lose()          if self.state ~= "lose" then self.state = "lose" end end
function ResultsScreen:loadingScreen() self.state = "loading" end

function ResultsScreen:draw(scale)
    scale = scale or 1
    local frameIdx = FRAME[self.state] or 1
    local quad = self.quads[frameIdx]
    if not quad then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, quad, 0, 0, 0, scale, scale)
end
