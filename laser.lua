-- Laser module. 
-- Allows toggling/pulsing of laser
-- Has global relay for main power shutdown

local m = {}

m.pin = 2 -- laser TTL
m.pinRelay = 3 -- relay to main power supply
m.tmrPulse = 3
m.isOn = false
m.isInitted = false

-- user can set this to ensure power is not above max
m.maxDuty = 1023

-- Make sure to call this first
function m.init()
  
  if m.isInitted then
    return
  end
  
  -- TODO setup the i2c current sensor
  
  -- setup TTL
  gpio.mode(m.pin, gpio.OUTPUT)
  gpio.write(m.pin, gpio.LOW)
  
  -- setup relay
  -- relay requires high or low (not float) to turn on
  -- so set to float to turn off main power relay
  gpio.mode(m.pinRelay, gpio.INPUT)
  -- maybe relay requires OPENDRAIN to turn off
  -- gpio.mode(m.pinRelay, gpio.OPENDRAIN)
  
  m.isOn = false
  m.isInitted = true
  
end

-- Turn relay on
function m.relayOn()
  m.init()
  -- relay requires high or low (not float) to turn on
  gpio.mode(m.pinRelay, gpio.OUTPUT)
  gpio.write(m.pinRelay, gpio.LOW)
  -- gpio.write(m.pinRelay, gpio.HIGH)
  print("Relay On")
end

-- Turn relay off
function m.relayOff()
  m.init()
  -- relay requires float to turn off
  gpio.mode(m.pinRelay, gpio.INPUT)
  print("Relay Off")
end

-- Turn laser on via TTL pin
-- You should consider using pwmOn instead
function m.on()
  m.init()
  gpio.write(m.pin, gpio.HIGH)
  print("Laser On")
end

-- Turn laser off via TTL pin
-- You should consider using pwmOff instead
function m.off()
  m.init()
  gpio.write(m.pin, gpio.LOW)
  print("Laser Off")
end

-- pulse the laser for a delay of ms
function m.pulseFor(delay)
  m.init()
  local d = 100
  if delay ~= nil then
    d = delay
  end
  tmr.alarm(m.tmrPulse, d, tmr.ALARM_AUTO, m.pulseStop)
  m.on()
end

function m.pulseStop()
  tmr.stop(m.tmrPulse)
  m.off()
end

-- frequency in hertz. max 1000hz or 1khz
-- duty cycle. 0 is 0% duty. 1023 is 100% duty. 512 is 50%.
function m.pwmOn(freqHz, duty)
  if (duty > m.maxDuty) then duty = m.maxDuty end
  print("Laser pwmOn hz:", freqHz, "duty:", duty)
  pwm.setup(m.pin, freqHz, duty)
  pwm.start(m.pin)
  return duty
end

function m.pwmOff()
  print("Laser pwmOff")
  pwm.stop(m.pin)  
end

function m.pwmSetMaxDuty(duty)
  m.maxDuty = duty
end

return m
