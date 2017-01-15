-- Cayenn Protocol for ChiliPeppr
-- This module does udp/tcp sending/receiving to talk with SPJS
-- or have the browser talk direct to this ESP8266 device.
-- This module has methods for connecting to wifi, then initting
-- UDP servers, TCP servers, and sending a broadcast announce out.
-- The broadcast announce let's any listening SPJS know we're alive.
-- SPJS then reflects that message to any listening browsers like
-- ChiliPeppr so they know a device is available on the network.
-- Then the browser can send commands back to this device.

local M = {}

M.port = 8988
M.myip = nil
M.sock = nil
M.jsonTagTable = nil

M.isInitted = false

-- When you are initting you can pass in tags to describe your device
-- You should use a format like this:
-- opts = {}
-- opts.Name = "LaserUV"
-- opts.Desc = "Control the BDR209 UV laser"
-- opts.Icon = "https://raw.githubusercontent.com/chilipeppr/widget-cayenn/master/laser.png"
-- opts.Widget = "com-chilipeppr-widget-laser"
-- cayenn.init(opts)
function M.init(jsonTagTable)
  
  -- save the jsonTagTable
  if jsonTagTable ~= nil then
    M.jsonTagTable = jsonTagTable
  end
  
  if M.isInitted then
    print("Already initted")
    return
  end
  
  print("Init...")

  -- figure out if i have an IP
  M.myip = wifi.sta.getip()
  if M.myip == nil then
    print("Connecting to wifi.")
    M.setupWifi()
  else 
    print("My IP: " .. M.myip)
    M.isInitted = true

    -- create socket for outbound UDP sending
    M.sock = net.createConnection(net.UDP, 0)

    -- create server to listen to incoming udp
    M.initUdpServer()
    
    -- create server to listen to incoming tcp
    M.initTcpServer()
    
    -- send our announce
    M.sendAnnounceBroadcast(M.jsonTagTable)
  
    if M.listenerOnConnected ~= nil then
      M.listenerOnConnected()
    end
  end 
  
end

function M.createAnnounce(jsonTagTable)
  
  local a = {}
  a.Announce = "i-am-a-client"
  a.MyDeviceId = "chip:" .. node.chipid() .. "-mac:" .. wifi.sta.getmac()
  
  -- if jsonTagTable.Widget then
  --   a.Widget = jsonTagTable.Widget
  --   -- jsonTagTable.Widget = nil
  -- elseif M.jsonTagTable.Widget then
  --   a.Widget = M.jsonTagTable.Widget
  -- else
  --   a.Widget = "com-chilipeppr-widget-undefined"
  -- end
  
  -- see if there is a jsontagtable passed in as extra meta
  local jsontag = ""
  if jsonTagTable then
    ok, jsontag = pcall(cjson.encode, jsonTagTable)
    if ok then
      -- print("Adding jsontagtable" .. jsontag)
    else
      print("fail encode jsontag")
    end
  end

  a.JsonTag = jsontag
  
  local ok, json = pcall(cjson.encode, a)
  if ok then
    --print("Encoded json for announce: " .. json)
  else
    print("fail encode json")
  end
  print("Announce: " .. json)
  return json
end

-- send announce to broadcast addr so spjs 
-- knows of our existence
function M.sendAnnounceBroadcast(jsonTagTable)
  -- if M.isInitted == false then
  --   -- print("You must init first.")
  --   return 
  -- end
  
  local bip = wifi.sta.getbroadcast()
  --print("Broadcast addr:" .. bip)
  
  -- if there was no jsonTagTable passed in, then used 
  -- stored one 
  if not jsonTagTable then 
    jsonTagTable = M.jsonTagTable
  end 
  
  print("Announce to ip: " .. bip)
  M.sock:connect(M.port, bip)
  M.sock:send(M.createAnnounce(jsonTagTable))
  M.sock:close()
  
end

-- Workhorse of this library to send broadcast msg back 
-- to SPJS so it can regurgitate to ChiliPeppr
-- Keep in mind that your custom payload is in jsonTagTable 
-- and that gets embedded in the larger JSON packet that
-- describes this device 
function M.sendBroadcast(jsonTagTable, ip)
  
  -- if M.isInitted == false then
  --   -- print("You must init first.")
  --   return 
  -- end
  
  -- we need to attach deviceid 
  local a = {}
  
  -- see if there is a jsontagtable passed in as extra meta
  local jsontag = ""
  if jsonTagTable then
    ok, jsontag = pcall(cjson.encode, jsonTagTable)
    if ok then
      -- print("Adding jsontagtable" .. jsontag)
    else
      print("fail encode jsontag")
      jsonTagTable = nil 
      jsontag = nil 
    end
  end

  a.JsonTag = jsontag
  jsontag = nil -- delete from memory
  jsonTagTable = nil -- delete from memory
  
  a.MyDeviceId = "chip:" .. node.chipid() .. "-mac:" .. wifi.sta.getmac()

  local ok, json = pcall(cjson.encode, a)
  if ok then
    --print("Encoded json for announce: " .. json)
  else
    print("fail encode json")
  end
  
  a = nil -- delete it 
  
  -- local bip = wifi.sta.getbroadcast()
  if ip == nil then 
    ip = {} 
    ip[wifi.sta.getbroadcast()] = true
  end 
  --print("Broadcast addr:" .. bip)
  
  -- local msg = cjson.encode(jsonTagTable)
  -- local msg = cjson.encode(a)
  -- print("Sending UDP msg: " .. json .. " to ip: " .. bip)
  for key,value in pairs(ip) do 
    -- print(key,value) 
    -- print("Sending UDP to ip: " .. key .. ", msg: " .. json)
    M.sock:connect(M.port, key)
    M.sock:send(json)
    M.sock:close()
  end
  
  ip = nil -- delete it 
  json = nil -- delete it 
  
end

function M.setupWifi()
  -- setwifi
  wifi.setmode(wifi.STATION)
  -- longest range is b
  wifi.setphymode(wifi.PHYMODE_N)
  --Connect to access point automatically when in range
  
  -- for some reason digits in password seem to get mangled
  -- so splitting the password across two concatenated strings seems to solve problem
  -- for example "pass" .. "word"
  wifi.sta.config("WIFINETWORKNAME", "password")
  wifi.sta.connect()
  
  --register callback
  wifi.sta.eventMonReg(wifi.STA_IDLE, function() print("IDLE") end)
  --wifi.sta.eventMonReg(wifi.STA_CONNECTING, function() print("STATION_CONNECTING") end)
  wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function() print("WRONG_PASSWORD") end)
  wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function() print("NO_AP_FOUND") end)
  wifi.sta.eventMonReg(wifi.STA_FAIL, function() print("CONN_FAIL") end)
  wifi.sta.eventMonReg(wifi.STA_GOTIP, M.gotip)
  
  --register callback: use previous state
  wifi.sta.eventMonReg(wifi.STA_CONNECTING, function(previous_State)
      if(previous_State==wifi.STA_GOTIP) then 
        print ("Reconnect")
          -- print("Station lost connection with access point\n\tAttempting to reconnect...")
      else
        print("CONNECTING")
      end
  end)
  
  --start WiFi event monitor with default interval
  wifi.sta.eventMonStart(1000)
  
end

function M.gotip()
  -- print("STATION_GOT_IP")
  M.myip = wifi.sta.getip()
  print("My IP: " .. M.myip)
  -- stop monitoring now since we're connected
  wifi.sta.eventMonStop()
  -- print("Stopped monitoring") -- wifi events since connected.")
  
  -- make sure we are initted
  M.init()
end

-- this property and method let an external object attach a
-- listener to the incoming UDP cmd
M.listenerOnConnected = nil
function M.addListenerOnConnected(listenerCallback)
  M.listenerOnConnected = listenerCallback
  -- print("Attached listener to incoming UDP cmd")
end

function M.initUdpServer()
  M.udpServer = net.createServer(net.UDP)
  --M.udpServer:on("connection", M.onUdpConnection)
  M.udpServer:on("receive", M.onUdpRecv) 
  M.udpServer:listen(8988)
  -- print("UDP Server started on port 8988")
end

function M.onUdpConnection(sck)
  -- print("UDP connection.")
  --ip, port = sck:getpeer()
  --print("UDP connection. from: " .. ip)
end

function M.onUdpRecv(sck, data)
  print("UDP Recv " .. data)
  if (M.listenerOnIncomingUdpCmd) then
    -- see if json
    if string.sub(data,1,1) == "{" then
      -- catch json errors
      local succ, results = pcall(function()
      	return cjson.decode(data)
      end)
      
      -- see if we could parse
      if succ then
      	data = results --cjson.decode(data)
        -- data.peerIp = peer
      else
      	print("Err parse JSON")
      	return
      end
      
    end
    M.listenerOnIncomingUdpCmd(data)
  end
end

-- this property and method let an external object attach a
-- listener to the incoming UDP cmd
M.listenerOnIncomingUdpCmd = nil
function M.addListenerOnIncomingUdpCmd(listenerCallback)
  M.listenerOnIncomingUdpCmd = listenerCallback
  -- print("Attached listener to incoming UDP cmd")
end

function M.removeListenerOnIncomingUdpCmd(listenerCallback)
  M.listenerOnIncomingUdpCmd = nil
  -- print("Removed listener on incoming UDP cmd")
end

function M.initTcpServer()
  M.tcpServer = net.createServer(net.TCP)
  M.tcpServer:listen(8988, M.onTcpListen)
  
  -- print("TCP Server started on port 8988")
end

function M.onTcpListen(conn)
  conn:on("receive", M.onTcpRecv)
end

function M.onTcpConnection(sck)
  -- print("TCP connection.")
  --ip, port = sck:getpeer()
  --print("UDP connection. from: " .. ip)
end

function M.onTcpRecv(sck, data)
  local peer = sck:getpeer()
  print("TCP Recv " .. data .. ", Peer:" .. peer)
  if (M.listenerOnIncomingCmd) then
    -- see if json
    if string.sub(data,1,1) == "{" then
      -- catch json errors
      local succ, results = pcall(function()
      	return cjson.decode(data)
      end)
      
      -- see if we could parse
      if succ then
      	data = results --cjson.decode(data)
        data.peerIp = peer
      else
      	print("Err parse JSON")
      	return
      end
      
    end
    M.listenerOnIncomingCmd(data)
  end
end

-- this property and method let an external object attach a
-- listener to the incoming TCP command
M.listenerOnIncomingCmd = nil
function M.addListenerOnIncomingCmd(listenerCallback)
  M.listenerOnIncomingCmd = listenerCallback
  -- print("Attached listener to incoming TCP cmd")
end

function M.removeListenerOnIncomingCmd(listenerCallback)
  M.listenerOnIncomingCmd = nil
  -- print("Removed listener on incoming TCP cmd")
end

return M

