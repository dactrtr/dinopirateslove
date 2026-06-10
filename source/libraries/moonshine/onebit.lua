--[[
  onebit.lua — Playdate-style 1-bit duotone effect for Moonshine.

  Converts the rendered (full color) image to two tones, mimicking how the
  Playdate takes colour images and dithers them down to 1-bit:

    luminance below threshold -> darkColor  (e.g. dark grey instead of black)
    luminance above threshold -> lightColor (e.g. ochre instead of white)

  When `dither` is enabled, a 4x4 ordered (Bayer) matrix is applied on the
  VIRTUAL pixel grid (not the upscaled screen pixels) so the dithering reads
  as chunky Playdate-sized dots rather than invisible sub-pixel noise.

  Parameters (all settable via moonshine):
    dark     : {r,g,b}  colour for the "black" tone   (default dark grey)
    light    : {r,g,b}  colour for the "white" tone    (default ochre)
    threshold: float    luminance cut point 0..1       (default 0.5)
    dither   : 0|1      enable ordered dithering        (default 1)
    virtual  : {w,h}    virtual resolution for dither   (default 400,240)
]]--

return function(moonshine)
  local shader = love.graphics.newShader[[
    extern vec3  dark;
    extern vec3  light;
    extern float threshold;
    extern float dither;
    extern vec2  virtual;

    // 4x4 Bayer ordered-dither matrix, normalised to (0..1).
    float bayer4x4(vec2 p) {
      int x = int(mod(p.x, 4.0));
      int y = int(mod(p.y, 4.0));
      int i = x + y * 4;
      float m = 0.0;
      if      (i == 0)  m = 0.0;    else if (i == 1)  m = 8.0;
      else if (i == 2)  m = 2.0;    else if (i == 3)  m = 10.0;
      else if (i == 4)  m = 12.0;   else if (i == 5)  m = 4.0;
      else if (i == 6)  m = 14.0;   else if (i == 7)  m = 6.0;
      else if (i == 8)  m = 3.0;    else if (i == 9)  m = 11.0;
      else if (i == 10) m = 1.0;    else if (i == 11) m = 9.0;
      else if (i == 12) m = 15.0;   else if (i == 13) m = 7.0;
      else if (i == 14) m = 13.0;   else if (i == 15) m = 5.0;
      // +0.5 centres each cell; /16 normalises to 0..1.
      return (m + 0.5) / 16.0;
    }

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pixel_coords) {
      vec4 pixel = Texel(texture, tc);

      // Perceptual luminance (Rec.601), same idea the Playdate uses.
      float lum = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));

      // Compare against threshold, optionally biased by the ordered-dither
      // pattern sampled on the virtual pixel grid.
      float cut = threshold;
      if (dither > 0.5) {
        vec2 vpix = floor(tc * virtual);
        // Re-centre the matrix around 0 so it nudges the cut up/down evenly.
        cut += (bayer4x4(vpix) - 0.5);
      }

      vec3 outColor = (lum < cut) ? dark : light;
      return vec4(outColor, pixel.a) * color;
    }]]

  local setters = {}

  local function asVec3(v, fallback)
    if type(v) == "table" and #v >= 3 then
      local r, g, b = v[1], v[2], v[3]
      if r > 1 or g > 1 or b > 1 then r, g, b = r/255, g/255, b/255 end
      return {r, g, b}
    end
    return fallback
  end

  setters.dark = function(v)
    shader:send("dark", asVec3(v, {0.18, 0.18, 0.18}))
  end
  setters.light = function(v)
    shader:send("light", asVec3(v, {0.78, 0.65, 0.36}))
  end
  setters.threshold = function(v)
    shader:send("threshold", v or 0.5)
  end
  setters.dither = function(v)
    if type(v) == "boolean" then v = v and 1 or 0 end
    shader:send("dither", v or 0)
  end
  setters.virtual = function(v)
    if type(v) == "table" and #v >= 2 then
      shader:send("virtual", {v[1], v[2]})
    end
  end

  return moonshine.Effect{
    name      = "onebit",
    shader    = shader,
    setters   = setters,
    defaults  = {
      dark      = {0.18, 0.18, 0.18},   -- dark grey instead of pure black
      light     = {0.78, 0.65, 0.36},   -- ochre instead of pure white
      threshold = 0.5,
      dither    = 1,
      virtual   = {400, 240},
    }
  }
end
