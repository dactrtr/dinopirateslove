--[[
Outline effect for moonshine
Adds a 1-pixel border of a specified color.
]]--

return function(moonshine)
  local shader = love.graphics.newShader[[
    extern vec2 stepSize;
    extern vec4 outlineColor;
    extern number thickness;

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 _) {
      vec4 pixel = Texel(texture, tc);
      
      // If the current pixel is not fully opaque, check its neighbors
      if (pixel.a < 1.0) {
        float alpha = 0.0;
        
        // Sample neighbors with thickness
        // We use 8 cardinal/diagonal directions for better coverage
        vec2 ts = stepSize * thickness;
        
        alpha += Texel(texture, tc + vec2(ts.x, 0.0)).a;
        alpha += Texel(texture, tc + vec2(-ts.x, 0.0)).a;
        alpha += Texel(texture, tc + vec2(0.0, ts.y)).a;
        alpha += Texel(texture, tc + vec2(0.0, -ts.y)).a;
        
        // Diagonals for smoother corners at higher thickness
        alpha += Texel(texture, tc + vec2(ts.x, ts.y)).a;
        alpha += Texel(texture, tc + vec2(-ts.x, ts.y)).a;
        alpha += Texel(texture, tc + vec2(ts.x, -ts.y)).a;
        alpha += Texel(texture, tc + vec2(-ts.x, -ts.y)).a;
        
        // If any neighbor is opaque, this pixel should be part of the outline
        if (alpha > 0.0) {
          return outlineColor * color;
        }
      }
      
      return pixel * color;
    }
  ]]

  local setters = {}
  setters.color = function(c)
    shader:send("outlineColor", c)
  end
  setters.thickness = function(t)
    shader:send("thickness", tonumber(t) or 1)
  end

  local draw = function(buffer)
    local front, back = buffer()
    shader:send("stepSize", {1 / back:getWidth(), 1 / back:getHeight()})
    love.graphics.setCanvas(front)
    love.graphics.clear(0,0,0,0)
    love.graphics.setShader(shader)
    love.graphics.draw(back)
  end

  return moonshine.Effect{
    name = "outline",
    shader = shader,
    setters = setters,
    draw = draw,
    defaults = {color = {1, 1, 1, 1}}
  }
end
