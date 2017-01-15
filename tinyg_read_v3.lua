-- Read the inputs from TinyG
-- We need to watch Coolant Pin
-- We also need to watch the A axis step/dir pins.

local m = {}
-- m = {}

m.pinCoolant = 5
m.pinADir = 6
m.pinAStep = 7

-- global ID counter. we increment this each time we see 
-- a signal on the coolant pin 
m.idCounter = -1

function m.init()
  -- gpio.mode(m.pinCoolant, gpio.INPUT)
  gpio.mode(m.pinCoolant, gpio.INT) --, gpio.PULLUP)
  gpio.mode(m.pinADir, gpio.INT)
  gpio.mode(m.pinAStep, gpio.INT)
  gpio.trig(m.pinCoolant, "both", m.pinCoolantCallback)
  print("Coolant: " .. tostring(gpio.read(m.pinCoolant)) ..
    ", ADir: " .. tostring(gpio.read(m.pinADir)) ..
    ", AStep: " .. tostring(gpio.read(m.pinAStep))
    )
end

function m.status()
  print("Coolant: " .. tostring(gpio.read(m.pinCoolant)) ..
    ", ADir: " .. tostring(gpio.read(m.pinADir)) ..
    ", AStep: " .. tostring(gpio.read(m.pinAStep))
    )
end

m.lastTime = 0
m.lookingFor = gpio.HIGH
m.lookingCtr = 0
function m.pinCoolantCallback(level)
  -- we get called here on rising and falling edge
  if m.lookingFor == gpio.HIGH then
    -- read 10 more times, and if we get good reads, trust it
    local readCtr = 0
    for i = 0, 5 do
      if gpio.read(m.pinCoolant) == gpio.HIGH then
        readCtr = readCtr + 1
      end
    end
    
    if readCtr > 3 then
      -- treat that as good avg
      m.idCounter = m.idCounter + 1
      -- print("Got coolant pin. idCounter: " .. m.idCounter)
      m.onIdChange()
      m.lookingFor = gpio.LOW
    else
      -- print("Failed avg")
    end
    
  else
    -- looking for gpio.LOW
    -- read 10 more times, and if we get good reads, trust it
    local readCtr = 0
    for i = 0, 5 do
      if gpio.read(m.pinCoolant) == gpio.LOW then
        readCtr = readCtr + 1
      end
    end
    
    if readCtr > 3 then
      -- treat that as good avg
      -- print("Trusting low")
      m.lookingFor = gpio.HIGH
    else
      -- print("Failed avg")
    end
    
  end
  
  gpio.trig(m.pinCoolant, "both")

end

function m.resetIdCounter()
  m.idCounter = -1
  m.onIdChange()
  print("Reset idCounter: " .. m.idCounter)
end

function m.getIdCounter()
  return m.idCounter
end 

-- this property and method let an external object attach a
-- listener to the counter change
m.listenerOnIdChange = null
function m.addListenerOnIdChange(listenerCallback)
  m.listenerOnIdChange = listenerCallback
  -- print("Attached listener to Id Change")
end

function m.removeListenerOnIdChange(listenerCallback)
  m.listenerOnIdChange = null
  -- print("Removed listener on Id Change")
end

function m.onIdChange()
  if m.listenerOnIdChange then
    m.listenerOnIdChange(m.idCounter)
  end
end

-- this property and method let an external object attach a
-- listener to the ADir pin 
m.listenerOnADir = null
function m.addListenerOnADir(listenerCallback)
  m.listenerOnADir = listenerCallback
  -- print("Attached listener to ADir pin")
end

function m.removeListenerOnADir(listenerCallback)
  m.listenerOnADir = null
  -- print("Removed listener on ADir pin")
end

-- this property and method let an external object attach a
-- listener to the AStep pin 
m.listenerOnAStep = null
function m.addListenerOnAStep(listenerCallback)
  m.listenerOnAStep = listenerCallback
  -- print("Attached listener to AStep pin")
end

function m.removeListenerOnAStep(listenerCallback)
  m.listenerOnAStep = null
  -- print("Removed listener on AStep pin")
end

function m.pinADirCallback(level)
  gpio.trig(m.pinADir, "both")
  -- this method is called when the ADir pin has an interrupt
  -- we need to simply regurgitate it to appropriate listener
  print("ADir: " .. level)
  -- call listener 
  if m.listenerOnADir then 
    m.listenerOnADir()
  end 
  -- print("Got coolant pin. idCounter: " .. m.idCounter)
end

function m.pinAStepCallback(level)
  gpio.trig(m.pinAStep, "both")
  -- this method is called when the AStep pin has an interrupt
  -- we need to simply regurgitate it to appropriate listener
  print("AStep: " .. level)
  -- call listener 
  if m.listenerOnAStep then 
    m.listenerOnAStep()
  end 
end



return m
-- m.init()
