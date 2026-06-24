levelsLDTK = {}
-- Match the Playdate: the procedural pool is floor4 only (floor3 was dropped
-- upstream; its 5 rooms are not referenced by floor4).
love.filesystem.load('assets/data/levels_floor4.lua')()
