-- Main entry point for Laser UV Cayenn device

-- set freq to highest possible
node.setcpufreq(node.CPU160MHZ)

cnet = require('cayenn_net')
laser = require('laser')
cnc = require('tinyg_read_v3')
queue = require("cayenn_queue")
led = require("ws2812_4strip")

-- led white to show start
led.init()
led.inject(string.char(255,255,255))

opts = {}
opts.Name = "LaserUV"
opts.Desc = "Control the BDR209 UV laser"
opts.Icon = "https://raw.githubusercontent.com/chilipeppr/widget-cayenn/master/laser.png"
opts.Widget = "com-chilipeppr-widget-laser"
-- opts.WidgetUrl = "https://github.com/chilipeppr/widget-laser/auto-generated.html"

-- define commands supported
cmds = {
  "ResetCtr", "GetCtr", "GetCmds", "GetQ", "WipeQ", "CmdQ", "Mem",
  "LaserBoot", "LaserShutdown",
  'PwmOn {Hz,Duty} (Max Hz:1000, Max Duty:1023)', "PwmOff",
  'PulseFor {ms}',
  'MaxDuty {Duty}'
}

-- this is called by the cnc library when the coolant pin changes
function onCncCounter(counter)
  print("Got CNC pin change. counter:" .. counter)
  local cmd = queue.getId(counter)
  onCmd(cmd)
  -- led green to show increment
  if counter == -1 then
    led.inject(string.char(255,255,0))
  else
    led.inject(string.char(255,0,0))
  end
end

-- this is called by Cayenn when an incoming cmd comes in
-- from the network, i.e. from SPJS. These are TCP commands so
-- they are guaranteed to come in (vs UDP which could drop)
function onCmd(payload)
  
  if (type(payload) == "table") then
      -- print("is json")
      -- print("Got incoming Cayenn cmd JSON: " .. cjson.encode(payload))
      
      -- See what cmd
      if payload.Cmd == "LaserBoot" then
        laser.relayOn()
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd})
        -- led purple to show boot
        led.inject(string.char(0,100,100))
        -- print("Turned on relay to laser driver. Takes 3 secs to boot.")
      elseif payload.Cmd == "LaserShutdown" then
        laser.relayOff()
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd})
        -- led white to show shutdown
        led.inject(string.char(30,30,30))
        -- print("Turned off relay to laser driver")
      elseif payload.Cmd == "MaxDuty" then
        -- force a max duty to control laser power
        laser.pwmSetMaxDuty(payload.Duty)
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["MaxDuty"] = payload.Duty})
      elseif payload.Cmd == "PulseFor" then
        -- should have been given milliseconds to pulse for
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd})
        -- led.blink(1)
        -- run pulse after sending resp so no cpu is being used
        -- so we get precise timing
        laser.pulseFor(payload.ms)
        -- print("Turned off relay to laser driver")
      elseif payload.Cmd == "PwmOn" then
        -- should have been given milliseconds to pulse for
        
        if payload.Hz == nil or payload.Duty == nil then
          cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Err"] = "Hz or Duty not specified"})
        elseif 'number' ~= type(payload.Hz) or 'number' ~= type(payload.Duty) then
          cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Err"] = "Hz or Duty not a number"})
        elseif payload.Hz > 1000 then
          cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Err"] = "Hz " .. payload.Hz .. " too high", ["Hz"] = payload.Hz})
        elseif payload.Hz <= 0 then
          cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Err"] = "Hz " .. payload.Hz .. " too low", ["Hz"] = payload.Hz})
        elseif payload.Duty > 1023 then
          cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Err"] = "Duty " .. payload.Duty .. " too high"})
        else
          local actualDuty = laser.pwmOn(payload.Hz, payload.Duty)
          cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = "PwmOn", ["Hz"] = payload.Hz, ["Duty"] = actualDuty})
          led.on(0,0,255)
        end
      elseif payload.Cmd == "PwmOff" then
        -- should have been given milliseconds to pulse for
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = "PwmOff"})
        laser.pwmOff()
        led.on(10,0,0)
      elseif payload.Cmd == "ResetCtr" then
        cnc.resetIdCounter()
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Ctr"] = cnc.getIdCounter()})
        -- led.inject(string.char(10,0,0))
      elseif payload.Cmd == "GetCtr" then
        -- cnc.resetIdCounter()
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Ctr"] = cnc.getIdCounter()})
        led.inject(string.char(0,0,10))
      elseif payload.Cmd == "GetCmds" then
        local resp = {}
        resp.Resp = "GetCmds"
        resp.Cmds = cmds
        resp.TransId = payload.TransId
        -- resp.CmdsMeta = cmdsMeta
        cnet.sendBroadcast(resp)
        led.inject(string.char(0,0,10))
      elseif payload.Cmd == "GetQ" then
        -- this method will send slowly as not to overwhelm
        queue.send(function(t) cnet.sendBroadcast(t); led.inject(string.char(0,0,10)) end, payload.TransId)
      elseif payload.Cmd == "WipeQ" then
        -- queue = {}
        -- print("Wiped queue: " .. cjson.encode(queue))
        queue.wipe()
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd})
        led.inject(string.char(0,0,10))
      elseif payload.Cmd == "CmdQ" then
        -- queuing cmd. we must have ID.
        if payload.Id == nil then
          -- print("Error queuing command. It must have an ID")
          return
        end
        if payload.RunCmd == nil then
          -- print("Error queuing command. It must have a RunCmd like RunCmd:{Cmd:AugerOn,Speed:10}.")
          return
        end
        -- wipe the peerIp cuz don't need it
        payload.peerIp = nil
        -- print("Queing command")
        --queue[payload.Id] = payload.RunCmd
        payload.RunCmd.Id = payload.Id
        queue.add(payload.RunCmd)
        -- print("New queue: " .. cjson.encode(queue))
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Id"] = payload.Id, ["MemRemain"] = node.heap()})
        -- led.blink(1)
        led.inject(string.char(0,0,10))
      elseif payload.Cmd == "Mem" then
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["MemRemain"] = node.heap()})
        -- led.blink(2)
        led.inject(string.char(0,0,10))
      elseif payload["Announce"] ~= nil then
        -- do nothing. 
        if payload.Announce == "i-am-your-server" then
          -- perhaps store this ip in future
          -- so we know what our server is
        end
        led.inject(string.char(10,0,10))
      else
        cnet.sendBroadcast({["TransId"] = payload.TransId, ["Resp"] = payload.Cmd, ["Err"] = "Unsupported cmd"})
        -- print("Got cmd we do not understand. Huh?")
        -- led all red to show error
        led.inject(string.char(0,255,0))
      end
  else
      -- print("is string")
      -- print("Got incoming Cayenn cmd. str: ", payload)
  end
  
  -- led blue to show step
  -- led.inject(string.char(0,0,10))
end

-- this callback is called when an incoming UDP broadcast 
-- comes in to this device. typically this is just for 
-- Cayenn Discover requests to figure out what devices are on 
-- the network
function onIncomingBroadcast(cmd)
  -- print("Got incoming UDP cmd: ", cmd)
  if (type(cmd) == "table") then
    if cmd["Cayenn"] ~= nil then
      if cmd.Cayenn == "Discover" then
        -- somebody is asking me to announce myself
        cnet.sendAnnounceBroadcast()
      else
        -- print("Do not understand incoming Cayenn cmd")
      end
    elseif cmd["Announce"] ~= nil then
      if cmd.Announce == "i-am-your-server" then
        -- we should store the server address so we can send
        -- back TCP
        -- print("Got a server announcement. Cool. Store it. TODO")
      else 
        -- print("Got announce but not from a server. Huh?")
      end 
    else 
      -- print("Do not understand incoming UDP cmd")
    end
    
  else 
    -- print("Got incoming UDP as string")
  end
end

-- we get this callback when we are Wifi connected
function onConnected()
  -- print("Got callback after connected.")
  -- led.knightriderOff()
  led.inject(string.char(255,0,0))
end

-- show animating led while booting
-- led.init()
-- led.knightriderOn(1)

-- add listener to incoming cnet commands
cnet.addListenerOnIncomingCmd(onCmd)
cnet.addListenerOnIncomingUdpCmd(onIncomingBroadcast)
cnet.addListenerOnConnected(onConnected)

cnet.init(opts)
laser.init()
-- laser.pwmSetMaxDuty(100)

-- listen to coolant pin changes
cnc.addListenerOnIdChange(onCncCounter)
cnc.init()

-- setup our command queue
queue.init()

-- led.blink(6)
print("Mem left:" .. node.heap())

-- led off to show done booting
led.inject(string.char(0,0,0))