-- TEST CONFIGURATION FOR PLUNGERANG
-- Add this code to main.lua after PlayerData is loaded to enable plunger for testing
-- This is temporary and should be removed after testing

-- Enable plunger for testing (add after line 8 in main.lua)
--[[
function enablePlungerForTesting()
    PlayerData.items.hasPlunger = true
    PlayerData.skills.canPlungerang = true
    PlayerData.activeItem = 3
    printDebug("🧪 TEST MODE: Plunger enabled!")
end

-- Call this in love.load() after PlayerData is initialized
-- enablePlungerForTesting()
]]--

-- TESTING INSTRUCTIONS:
-- 1. Uncomment the code above and add the call to love.load()
-- 2. Run the game
-- 3. Press 'X' to test plungerang (must be moving in a direction first)
-- 4. Test constraints:
--    - Try while idle (should fail)
--    - Try while tiny (should fail - use 'E' to toggle size on minifier)
--    - Try launching second projectile while one is active (should fail)
-- 5. Test collisions with walls and enemies
-- 6. Verify projectile returns and player regains control

-- ALTERNATIVE: Place a plunger item in a test level
-- In LDtk editor, add an Items entity with type="plunger" to test collection
