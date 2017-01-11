-- WS2812 Library for Cayenn
-- This is for a 4 strip ws2812 setup 
-- The ws2812 on Lua requires pin D4
local led = {}

led.pin = 4 -- this is GPIO2

led.isInitted = false
led.buffer = nil

function led.init()
  ws2812.init()
  i = 0
  led.buffer = ws2812.newBuffer(4, 3)
  led.buffer:fill(0, 0, 0, 0)
  led.isInitted = true
end

-- example call led.on(255,0,0) -- goes all green
function led.on(b1, b2, b3)
  led.buffer:fill(b1, b2, b3)
  -- buffer:set(i%buffer:size() + 1, 0, 255, 0)
  ws2812.write(led.buffer)
end

function led.off()
  led.buffer:fill(0, 0, 0)
  -- buffer:set(i%buffer:size() + 1, 0, 255, 0)
  ws2812.write(led.buffer)
end

function led.set(index, color)
  led.buffer:set(index, color)
  ws2812.write(led.buffer)
end

-- this method has you inject a color and then it does
-- the knightrider effect per injection
led.i = 0
led.dir = 1
function led.inject(color)

  led.i = led.i + led.dir
  
  if led.i == 4 and led.dir == 1 then
    -- we are at end, reverse direction
    led.dir = -1
    -- print("reversing dir")
  elseif led.i == 1 and led.dir == -1 then
    led.dir = 1
    -- print("forward dir")
  end
  
  led.buffer:fade(3)
  led.buffer:set(led.i, color)
  ws2812.write(led.buffer)
  -- print("Did inject led")
end

return led