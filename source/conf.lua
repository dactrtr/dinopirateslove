-- conf.lua
function love.conf(t)
	t.identity = "DinoPirates"         -- Nombre de la carpeta de guardado
	t.version = "11.5"                 -- Versión de LÖVE
	t.console = false                  -- Mostrar la consola (true solo para debugging en PC)

	t.window.title = "My Game"               -- Window title
	t.window.icon = nil                      -- Window icon (use "icon.png" if you have one)
	t.window.width = 400                     -- Base game width
	t.window.height = 240                    -- Base game height
	t.window.borderless = false              -- Remove window border
	t.window.resizable = true                -- Allow window resizing
	t.window.minwidth = 400                  -- Minimum window width
	t.window.minheight = 240                 -- Minimum window height
	t.window.fullscreen = false               -- Start in fullscreen
	t.window.fullscreentype = "desktop"      -- "desktop" or "exclusive"
	t.window.vsync = 1                       -- Enable vertical sync (0=off, 1=on, -1=adaptive)
	t.window.msaa = 0                        -- Multi-sampling anti-aliasing samples (0, 2, 4, 8, 16)
	t.window.depth = nil                     -- Depth buffer bits
	t.window.stencil = nil                   -- Stencil buffer bits
	t.window.display = 1                     -- Monitor to use for fullscreen
	t.window.highdpi = false                 -- Enable high DPI mode
	t.window.usedpiscale = true              -- Use DPI scale factor
	t.window.x = nil                         -- Window x position
	t.window.y = nil     
	t.accelerometerjoystick = true       
	t.modules.audio = true                   -- Enable audio module
	t.modules.data = true                    -- Enable data module
	t.modules.event = true                   -- Enable event module
	t.modules.font = true                    -- Enable font module
	t.modules.graphics = true                -- Enable graphics module
	t.modules.image = true                   -- Enable image module
	t.modules.joystick = true                -- Enable joystick module
	t.modules.keyboard = true                -- Enable keyboard module
	t.modules.math = true                    -- Enable math module
	t.modules.mouse = true                   -- Enable mouse module
	t.modules.physics = true                 -- Enable physics module (Box2D)
	t.modules.sound = true                   -- Enable sound module
	t.modules.system = true                  -- Enable system module
	t.modules.thread = true                  -- Enable thread module
	t.modules.timer = true                   -- Enable timer module
	t.modules.touch = true                   -- Enable touch module (mobile)
	t.modules.video = true                   -- Enable video module
	t.modules.window = true 
	-- Resolución virtual (ajustable según tu juego)
	VIRTUAL_WIDTH  = 400              
	VIRTUAL_HEIGHT = 240
end