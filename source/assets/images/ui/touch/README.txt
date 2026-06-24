Touch control skin images
=========================

Drop PNGs here to replace the programmer-drawn touch controls (D-pad + A/B/pause).
Anything you don't provide keeps using the built-in vector drawing, so you can
skin one piece at a time.

Recommended sizes (virtual px; author at 2x for crisp pixel art — images are
scaled to fit and use nearest-neighbour filtering):
  - A / B buttons : ~38 x 38
  - pause button  : ~24 x 24
  - d-pad         : ~60 x 60

Wire them up either by editing the SKIN table at the top of
entities/UI/TouchControls.lua, or at runtime:

  local TouchControls = require 'entities.UI.TouchControls'
  TouchControls.setSkin{
      dpadBase  = 'assets/images/ui/touch/dpad.png',     -- static cross
      dpadUp    = 'assets/images/ui/touch/dpad_up.png',  -- optional "lit" overlays,
      dpadDown  = 'assets/images/ui/touch/dpad_down.png',--   shown while that dir is held
      dpadLeft  = 'assets/images/ui/touch/dpad_left.png',
      dpadRight = 'assets/images/ui/touch/dpad_right.png',
      A         = 'assets/images/ui/touch/btn_a.png',
      A_pressed = 'assets/images/ui/touch/btn_a_down.png',-- optional pressed variant
      B         = 'assets/images/ui/touch/btn_b.png',
      B_pressed = 'assets/images/ui/touch/btn_b_down.png',
      pause     = 'assets/images/ui/touch/btn_pause.png',
  }

Notes:
  - If a d-pad direction has no overlay image, a faint highlight is drawn on the
    active arm instead, so you still get press feedback with just dpadBase.
  - If a button has no *_pressed variant, the idle image is drawn slightly
    brighter while held.
  - A missing/typo'd path logs a warning and falls back to the vector drawing;
    it won't crash.
  - Control positions and hit sizes are the constants at the top of
    TouchControls.lua (DPAD_*, BUTTONS); images scale to those, so move/resize
    there if you change the layout.
