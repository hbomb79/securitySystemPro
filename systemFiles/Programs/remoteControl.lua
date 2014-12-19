runningProgram = shell.getRunningProgram()
if not pocket then LogFile.i('reactor Program Running... ', runningProgram) end
current = { --Anything in this table will be saved to file
  settings = {},
  devices = {
	PDA = {},
	Client = {},
	clientFunctions = {}
	},
  thisDevice={}
}
Events={}
elements = {}
currentPage="starting"
displayButtons = {}

if not term.isColor() then
	print('An Advanced Device Is Required, Color Support!')
	sleep(5)
	os.shutdown()
end


function btnInit(btnText, btnWidth, btnHeight, btnX, btnY, btnTC, btnBG, oTC, oBG, onClick, toggle, secBG, secTC, secText, parent) --Function to create button
	local btn = element.create(btnText, btnWidth, btnHeight, btnX, btnY, btnTC, btnBG, oTC, oBG, onClick, toggle, secBG, secTC, secText, parent) --Calls API to generate button
	table.insert(elements, btn) --Inserts into table so it can be scanned later
	element.opacity(btn, true) --Sets visibility to true
	return btn
end

function listBtnInit(btnText, btnWidth, btnHeight, btnX, btnY, btnTC, btnBG, oTC, oBG, onClick, toggle, secBG, secTC, secText, parent) --Function to create button
	local btn = element.create(btnText, btnWidth, btnHeight, btnX, btnY, btnTC, btnBG, oTC, oBG, onClick, toggle, secBG, secTC, secText, parent) --Calls API to generate button
	element.opacity(btn, true)
	return btn
end

function doClick(event, btn, x, y)
	functionToRun = element.tryClick(elements, x, y)
	if functionToRun then --Check click location
		functionToRun()
	end
end

function checkClick(event, btn, x, y)
	if not isSettingUp then
		doClick(event, btn, x, y)
	end
end

Peripheral = {
	GetPeripheral = function(_type)
		for i, p in ipairs(Peripheral.GetPeripherals()) do
			if p.Type == _type then
				return p
			end
		end
	end,

	Call = function(type, ...)
		local tArgs = {...}
		local p = GetPeripheral(type)
		peripheral.call(p.Side, unpack(tArgs))
	end,

	GetPeripherals = function(filterType)
		local peripherals = {}
		for i, side in ipairs(peripheral.getNames()) do
			local name = peripheral.getType(side):gsub("^%l", string.upper)
			local code = string.upper(side:sub(1,1))
			if side:find('_') then
				code = side:sub(side:find('_')+1)
			end

			local dupe = false
			for i, v in ipairs(peripherals) do
				if v[1] == name .. ' ' .. code then
					dupe = true
				end
			end

			if not dupe then
				local _type = peripheral.getType(side)
				local isWireless = false
				if _type == 'modem' then
					if not pcall(function()isWireless = peripheral.call(sSide, 'isWireless') end) then
						isWireless = true
					end     
					if isWireless then
						_type = 'wireless_modem'
						name = 'W '..name
					end
				end
				if not filterType or _type == filterType then
					table.insert(peripherals, {Name = name:sub(1,8) .. ' '..code, Fullname = name .. ' ('..Capitalise(side)..')', Side = side, Type = _type, Wireless = isWireless})
				end
			end
		end
		return peripherals
	end,

	GetPeripheral = function(_type)
		for i, p in ipairs(Peripheral.GetPeripherals()) do
			if p.Type == _type then
				return p
			end
		end
	end,

	PresentNamed = function(name)
		return peripheral.isPresent(name)
	end,

	CallType = function(type, ...)
		local tArgs = {...}
		local p = Peripheral.GetPeripheral(type)
		return peripheral.call(p.Side, unpack(tArgs))
	end,

	CallNamed = function(name, ...)
		local tArgs = {...}
		return peripheral.call(name, unpack(tArgs))
	end
}

Capitalise = function(str)
	return str:sub(1, 1):upper() .. str:sub(2, -1)
end
-- Modem Functions Called For Info On Modems, Or To Change Modem Status
modem = {
  channels = {
    ping = 6019,
    request = 6021,
	reply = 6023,
  },
  isOpen = function(channel) --Returns if the channel is open or not
    Peripheral.CallType('wireless_modem', 'isOpen', channel)
  end,
  
  Open = function(channel) --Open a channel if not already open
    if not modem.isOpen(channel) then
	  Peripheral.CallType('wireless_modem', 'open', channel)
	end
  end, 
  
  Close = function(channel) --Close channel specified
    Peripheral.CallType('wireless_modem', 'close', channel)
  end,
  
  CloseAll = function() --Close all channels
    Peripheral.CallType('wireless_modem', 'closeAll')
  end, 
  
  Transmit = function(channel, replyChannel, message) --Transmit a message over the modem... The message is serialized first so it can hold data.... Use FormatMessage()
    Peripheral.CallType('wireless_modem', 'transmit', channel, replyChannel, textutils.serialize(message))
  end,
  	
  isPresent = function()
    if Peripheral.GetPeripheral('wireless_modem') == nil then
	  return false
	else
	  return true
	end
  end,

  RecieveMessage = function(_channel, messageID, timeout)
		open(_channel)
		local done = false
		local event, side, channel, replyChannel, message = nil
		Timeout(function()
			while not done do
				event, side, channel, replyChannel, message = os.pullEvent('modem_message')
				if channel ~= _channel then
					event, side, channel, replyChannel, message = nil
				else
					message = textutils.unserialize(message)
					message.content = textutils.unserialize(message.content)
					if messageID and messageID ~= message.messageID or (message.destinationID ~= nil and message.destinationID ~= os.getComputerID()) then
						event, side, channel, replyChannel, message = nil
					else
						done = true
					end
				end
			end
		end,
		timeout)
		return event, side, channel, replyChannel, message
	end,

  SendMessage = function(channel, message, reply, messageID, destinationID)
    reply = reply or modem.channels.reply
	modem.Open(channel)
	modem.Open(reply)
	local _message = modem.FormatMessage(message, messageID, destinationID)
	modem.Transmit(channel, reply, _message)
	return _message
  end,

  HandleMessage = function(event, side, channel, replyChannel, message, distance)
    message = textutils.unserialize(message)
	message.content = textutils.unserialize(message.content)
	  if pocket then 
	    if message.content == 'Ping!' or message.content =='OutOfRange' or message.content == true or message.content == false then
	      modem.Responder(event, side, channel, replyChannel, message, distance)
		end
	  elseif not pocket then
	    if message.content ~= 'Pong!' and message.content ~= 'OutOfRange' and message.content ~= 'Ping!' then
	      modem.Responder(event, side, channel, replyChannel, message, distance)
	    end
	  end
  end,

  FormatMessage = function(message, messageID, destinationID)
    return {
	  content = textutils.serialize(message),
  	  senderID = os.getComputerID(),
	  senderName = os.getComputerLabel(),
	  channel = channel,
	  replyChannel = reply,
	  messageID = messageID or math.random(10000),
	  destinationID = destinationID
    }
  end,
  
	Initialise = function()
		if modem.isPresent() then
			for n, m in pairs (rs.getSides()) do 
				if peripheral.getType(m) == "modem" then
					rednet.open(m)
					return
				end
			end
			error'No Modem Opened'
		end
	end,
}


function drawTitleBar()
	titleBar.draw('HbombOS Security Suite', 'Remote Control', colors.cyan, 256, 128, 256, 1)
end

function eventRegister(event, functionToRun)
	LogFile.i('Registered Event: '..event, runningProgram)
	if not Events[event] then
		Events[event] = {}
	end
	table.insert(Events[event], functionToRun)
end

function programEventLoop()
LogFile.i('programLoop Started', runningProgram)
  while true do
	sleep(0)
	printer.centered("Remote Control System On-line", 6)
	if current.thisDevice.type=="CLIENT" then printer.centered("Client Computer", 8) else printer.centered("Master Server", 8) end
	local event, arg1, arg2, arg3, arg4, arg5, arg6 = os.pullEventRaw()
	  if Events[event] then
		for i, e in ipairs(Events[event]) do
		  e(event, arg1, arg2, arg3, arg4, arg5, arg6)
		end
      end
   end
end

function hideElement(elem, visible)
	LogFile.i("Hide Element Args:"..tostring(elem).." : "..tostring(visible), runningProgram)
	if elem == "-a" then
		for _, i in ipairs(elements) do
			element.opacity(i, visible)
		end
	else
		element.opacity(elem, visible)
	end
end

function AdvSettings()
	changePage('masterChg')	
	while true do
		printer.centered('To change the Master PC You are using',6)
		printer.centered("you will have to remove your self from the", 7)
		printer.centered("client list. This is for security", 8)
		printer.centered("Go to the master PC and delete this client", 10)
		printer.centered('Click Next When You Have Deleted This Client', 19)
		local e, p1, p2, p3 = os.pullEvent()
		if e == "checkMaster" then 
			printer.centered('Checking With Master!', 19)
			rednet.send(current.settings.masterID, 'AmIYours')
			local id, msg = rednet.receive(5)
			if id == current.settings.masterID then
				if msg == 'true' then
					drawTitleBar()
					printer.centered('The master PC still has you registered', 6)
					printer.centered('You must delete the connection to this client', 8)
					printer.centered('Click Anywhere To Retry', 19)
					os.pullEvent('mouse_click')
					changePage('masterChg')
				elseif msg == 'false' then
					changePage('masterDel')
					printer.centered('You Have Successfully Removed This Client From The Master', 19)
					while true do
					drawTitleBar()
					nextBtn = btnInit("Confirm", nil, nil, termX-4-#"Confirm", 18, 1, colors.green, 1, 256, function() os.queueEvent("submit_Result") end, false, nil, nil, nil, nil)
					printer.centered("Enter the ID of the new master computer below", 6)
					printer.centered("click \"Confirm\" when your done!", 7)
					term.setCursorPos(termX/2-#"Master ID: ", 10)
					write"Master ID: "
					local input = uInput.eventN(5, nil, elements)
					if input ~= "" and input ~= tostring(os.getComputerID()) then
						printer.centered("Please Wait While We Ping That ID ("..input..")", 19)
						input = tonumber(input)
						rednet.send(tonumber(input), "Ping")
						local sender, message, protocol = rednet.receive(5)
						sender = sender or ""
						message = message or ""
						if tostring(sender) == tostring(input) and message == "Pong" then
							printer.centered("Master Computer Response Found", 19)
							sleep(2)
							tableClear()
							current.settings.masterID = input
							break
						else
							setupTitleBar()
							printer.centered("We did not get a response!", 6)
							printer.centered("Ensure the master computer is on-line and retry", 10)
							printer.centered("Click Anywhere To Continue", 19)
							os.pullEvent("mouse_click")
						end
					elseif input == "" then
						printer.centered("Please Enter An ID!", 19)
						sleep(0.5)
					elseif input == tostring(os.getComputerID()) then
						printer.centered("Enter the master PCs ID, Not Yours!", 19)
						sleep(0.5)
					end
				end
				tableClear()
				drawTitleBar()
				printer.centered("To finish registration please go to your master PC", 6)
				printer.centered("and use your settings page to register this as a client", 7)
				printer.centered("We don't do this here for security reasons.", 8)
				printer.centered("Click Anywhere to Finish", 19)
				os.pullEvent("mouse_click")
				SaveSettings()
				os.reboot()
				else
					drawTitleBar()
					printer.centered('Unknown response, Cannot Continue', 6)
					sleep(1)
					changePage('masterChg')
				end
			else
				drawTitleBar()
				printer.centered('No Response, Ensure master PC Is On-Line', 6)
				sleep(1)
				changePage('masterChg')
			end
		elseif e == 'mouse_click' then checkClick(e, p1, p2, p3)
			
		end
	end
end

function adminLogin()
	local f = fs.open('systemFiles/Security/adminPass', 'r')
	local adminPass = f.readLine()
	f.close()
	while true do
		loginCancel = false
		changePage('login')
		printer.centered('To Continue, You Must Enter Your', 6)
		printer.centered('Admin Password', 7)
		local text = 'Password: '
		term.setCursorPos(termX/2-#text, 10)
		write(text)
		local input = uInput.eventRead(20, '*', elements)
		if input ~= "" and loginCancel ~= true then
			if input == adminPass then
				return true	
			end
		elseif input == "" and not loginCancel then
			printer.centered('Enter A Password', 19)
			sleep(0.5)
		elseif loginCancel then
			return false
		end
	end
end

function changePage(newPage)
	term.setCursorBlink(false)
	tableClear()
	if (newPage) ~= "" then
		LogFile.i("Changing Page To: "..newPage, runningProgram)
		currentPage = newPage
	else
		errora.err("Cannot Change Page", "The Destination Page Has No Content, Please Report This Manually, Including Steps To Recreate.", true, false)
	end
	drawTitleBar()
	
	if currentPage == "main" and current.thisDevice.type == "MASTER" then
		clientButton = btnInit("Clients", nil, nil, termX/2-#"Clients"/2, 18, 1, colors.cyan, 1, 256, function() viewClients() changePage('main') end, false, nil, nil, nil, nil)
		deviceMng = btnInit("Settings", nil, nil, 2, 18, 1, colors.green, 1, 256, function() if adminLogin() then settings() end changePage('main') end, false, nil, nil, nil, nil)
	elseif currentPage == "main" and current.thisDevice.type == "CLIENT" then
		deviceMng = btnInit("Change Master", nil, nil, termX/2-#"Change Master"/2, 18, 1, colors.green, 1, 256, function() if adminLogin() then AdvSettings() end changePage('main') end, false, nil, nil, nil, nil)
	elseif currentPage == "action" then
		rsT = btnInit("Redstone Toggle", nil, nil, 2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('RedstoneToggle') end, false, nil, nil, nil, nil)
		rsP = btnInit("Redstone Pulse", nil, nil, 2, 12, 1, colors.cyan, 1, 256, function() os.queueEvent('RedstonePulse') end, false, nil, nil, nil, nil)
		OS = btnInit("CraftOS Options", nil, nil, 2, 14, 1, colors.cyan, 1, 256, function() os.queueEvent('OSop') end, false, nil, nil, nil, nil)
		back = nil
		back = btnInit("Return", nil, nil, termX/2-#"Return"/2, 18, 1, colors.red, 1, 256, function() os.queueEvent('back') end, false, nil, nil, nil, nil)
	elseif currentPage == "actionRST" then
		if pocket then
			right = btnInit('Right', nil, nil, 2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = 'right' end, true, colors.green, 1, 'Right', 'rsOut')
			right.toggleState = 2
			element.opacity(right, true)
			redstoneSide = 'right'
			left = btnInit('Left', nil, nil, right.x+right.width+2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = "left" end, true, colors.green, 1, 'Left', 'rsOut')
			top = btnInit('Top', nil, nil, left.x+left.width+2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide')  redstoneSide = "top" end, true, colors.green, 1, 'Top', 'rsOut')
			bottom = btnInit('Bottom', nil, nil, 5, 12, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide')  redstoneSide = "bottom" end, true, colors.green, 1, 'Bottom', 'rsOut')
			back = btnInit('Back', nil, nil, bottom.x+bottom.width+2, 12, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = "back" end, true, colors.green, 1, 'Back', 'rsOut')
			rsToggleState = btnInit('Turn ON', nil, nil, termX-4-#"Turn ON", 20, 1, colors.green, 1, 256, nil, true, colors.cyan, 1, 'Turn OFF', nil)
		else
			right = btnInit('Right', nil, nil, 5, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = 'right' end, true, colors.green, 1, 'Right', 'rsOut')
			right.toggleState = 2
			element.opacity(right, true)
			redstoneSide = 'right'
			left = btnInit('Left', nil, nil, right.x+right.width+2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = "left" end, true, colors.green, 1, 'Left', 'rsOut')
			top = btnInit('Top', nil, nil, left.x+left.width+2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide')  redstoneSide = "top" end, true, colors.green, 1, 'Top', 'rsOut')
			bottom = btnInit('Bottom', nil, nil, top.x+top.width+2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide')  redstoneSide = "bottom" end, true, colors.green, 1, 'Bottom', 'rsOut')
			back = btnInit('Back', nil, nil, bottom.x+bottom.width+2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = "back" end, true, colors.green, 1, 'Back', 'rsOut')
			rsToggleState = btnInit('Turn ON', nil, nil, go.x-go.width-2, 18, 1, colors.green, 1, 256, nil, true, colors.cyan, 1, 'Turn OFF', nil)
		end
		go = btnInit('Request', nil, nil, termX-4-#"Request", 18, 1, colors.green, 1, 256, function() os.queueEvent('send') end, false, nil, nil, nil, nil)
		returnback = btnInit("Return", nil, nil, 2, 18, 1, colors.red, 1, 256, function() os.queueEvent('back') end, false, nil, nil, nil, nil)
	elseif currentPage == "actionRSP" then
		if pocket then
			right = btnInit('Right', nil, nil, 2, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = 'right' end, true, colors.green, 1, 'Right', 'rsOut')
			right.toggleState = 2
			element.opacity(right, true)
			redstoneSide = 'right'
			left = btnInit('Left', nil, nil, right.x+right.width+2, 10, 1, colors.cyan, 1, 256, function() redstoneSide = "left" end, true, colors.green, 1, 'Left', 'rsOut')
			top = btnInit('Top', nil, nil, left.x+left.width+2, 10, 1, colors.cyan, 1, 256, function() redstoneSide = "top" end, true, colors.green, 1, 'Top', 'rsOut')
			bottom = btnInit('Bottom', nil, nil, 5, 12, 1, colors.cyan, 1, 256, function() redstoneSide = "bottom" end, true, colors.green, 1, 'Bottom', 'rsOut')
			back = btnInit('Back', nil, nil, bottom.x+bottom.width+2, 12, 1, colors.cyan, 1, 256, function() redstoneSide = "back" end, true, colors.green, 1, 'Back', 'rsOut')
		else
			right = btnInit('Right', nil, nil, 5, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('changeSide') redstoneSide = 'right' end, true, colors.green, 1, 'Right', 'rsOut')
			right.toggleState = 2
			element.opacity(right, true)
			redstoneSide = 'right'
			left = btnInit('Left', nil, nil, right.x+right.width+2, 10, 1, colors.cyan, 1, 256, function() redstoneSide = "left" end, true, colors.green, 1, 'Left', 'rsOut')
			top = btnInit('Top', nil, nil, left.x+left.width+2, 10, 1, colors.cyan, 1, 256, function() redstoneSide = "top" end, true, colors.green, 1, 'Top', 'rsOut')
			bottom = btnInit('Bottom', nil, nil, top.x+top.width+2, 10, 1, colors.cyan, 1, 256, function() redstoneSide = "bottom" end, true, colors.green, 1, 'Bottom', 'rsOut')
			back = btnInit('Back', nil, nil, bottom.x+bottom.width+2, 10, 1, colors.cyan, 1, 256, function() redstoneSide = "back" end, true, colors.green, 1, 'Back', 'rsOut')
		end
		
		go = btnInit('Request', nil, nil, termX-4-#"Request", 18, 1, colors.green, 1, 256, function() os.queueEvent('submit_Result') os.queueEvent('send') end, false, nil, nil, nil, nil)
		returnback = btnInit("Return", nil, nil, 2, 18, 1, colors.red, 1, 256, function() os.queueEvent('submit_Result') os.queueEvent('back') end, false, nil, nil, nil, nil)
	elseif currentPage == "masterChg" then
		nextBtn = btnInit('Next', nil, nil, termX-4-#"Next", 18, 1, colors.green, 1, 256, function() os.queueEvent('checkMaster') end, false, nil, nil, nil, nil)
	elseif currentPage == 'login' then
		loginBtn = btnInit('Login', nil, nil, termX-4-#"Next", 18, 1, colors.green, 1, 256, function() os.queueEvent('submit_Result') end, false, nil, nil, nil, nil)
		backBtn = btnInit('Return', nil, nil, 2, 18, 1, colors.red, 1, 256, function() os.queueEvent('submit_Result') loginCancel = true end, false, nil, nil, nil, nil)
	elseif currentPage == 'settings' then
		printer.centered("Welcome To Your Settings Page", 6)
		regClient = btnInit("Register Client", nil, 5, 4, 10, 1, colors.green, 1, 256, function() registerClient() changePage('settings') end, false, nil, nil, nil, nil)
		delClient = btnInit("Delete Client", nil, 5, termX-6-#"Delete Client", 10, 1, colors.green, 1, 256, function() unregisterClient() changePage('settings') end, false, nil, nil, nil, nil)
		pdaSetup = btnInit("PDA Setup", nil, nil, termX/2-#"PDA Setup"/2, 16, 1, colors.green, 1, 256, function() PDA() changePage('settings') end, false, nil, nil, nil, nil)
		back = btnInit("Return", nil, nil, termX/2-#"Return"/2, 18, 1, colors.red, 1, 256, function() os.queueEvent("goback") end, false, nil, nil, nil, nil)
	elseif currentPage == 'actionOSopt' then
		if pocket then sdBtn = btnInit("Shutdown", nil, nil, 4, 8, 1, colors.cyan, 1, 256, function() os.queueEvent('sd') end, false, nil, nil, nil, nil) else sdBtn = btnInit("Shutdown Client", nil, 5, 4, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('sd') end, false, nil, nil, nil, nil) end
		if pocket then rbBtn = btnInit("Reboot", nil, nil, 4, 10, 1, colors.cyan, 1, 256, function() os.queueEvent('rb') end, false, nil, nil, nil, nil) else rbBtn = btnInit("Reboot Client", nil, 5, termX-6-#"Reboot Client", 10, 1, colors.cyan, 1, 256, function() os.queueEvent('rb') end, false, nil, nil, nil, nil) end
		back = btnInit("Return", nil, nil, termX/2-#"Return"/2, 18, 1, colors.red, 1, 256, function() os.queueEvent("goback") end, false, nil, nil, nil, nil)
	else
		LogFile.w("Unknown Page ID", runningProgram)
	end
	
end

function checkPeripherals()
	LogFile.i("Peripherals Have Changed, Checking For Devices", runningProgram)
	if not modem.isPresent() then
		LogFile.w("No Modem Present", runningProgram)
		while not modem.isPresent() do
			printer.centered("This program uses rednet to communicate between", 6)
			printer.centered("other computers. We cannot detect a wireless modem", 7)
			printer.centered("on this PC please attach one to continue.", 8)
			printer.centered("Well Check When You Attach A Peripheral", 19)
			os.pullEvent()
			sleep(0)
		end
	end
	
	modem.Initialise()
end

local function loadingIcon()
	i = 0
	while true do
		i = i + 1
		logo1 = paintutils.loadImage('systemFiles/Images/Update/update1.nfp')
		logo2 = paintutils.loadImage('systemFiles/Images/Update/update2.nfp')
		logo3 = paintutils.loadImage('systemFiles/Images/Update/update3.nfp')
		loadX = termX/2-2
		loadY = 15
		paintutils.drawImage(logo1, loadX, loadY)
		sleep(0.1)
		paintutils.drawImage(logo2, loadX, loadY)
		sleep(0.1)
		paintutils.drawImage(logo3, loadX, loadY)
		sleep(0.1)
	end
end

function PDA()
	changePage('PDA')
	printer.centered('If you want to control these computers remotely', 6)
	printer.centered("then this is the way to go!", 7)
	printer.centered("This wizard will guide you through", 8)
	printer.centered("creating your mobile master controller",9 )
	printer.centered("The PDA communicates to the master computer", 11)
	printer.centered("this means a master PC is still required and", 12)
	printer.centered("must be in range of the client and yourself!", 13)
	printer.centered('Click Anywhere To Continue', 19)
	os.pullEvent('mouse_click')
	changePage('PDA2')
	printer.centered('The PDA installation is simple, simply insert', 6)
	printer.centered("a PDA into a disk drive next to this pc", 7)
	printer.centered("The PC will then copy the file to the", 10)
	printer.centered("pocket PC", 11)
	printer.centered("Press Left Or Right ALT To Exit", 19)
	while true do
		event, side = os.pullEvent()
		if event == 'disk' then
			if disk.hasData(side) then
				local path = disk.getMountPath(side)
				-- This script moves all the required files from the master PC to the Pocket computer
				if fs.exists(path.."/api/") then
					for i, v in ipairs(fs.list(path.."/api/")) do
						fs.delete(v)
					end
					fs.delete(path..'/api/')
				end
				fs.copy('/api/', path..'/api/')
				if fs.exists(path..'/startup') then fs.delete(path..'/startup') end 
				fs.copy('systemFiles/Programs/remoteControl.lua', path..'/startup')
				local pdaSettings = {
					settings = {},
					thisDevice = {}
				}
				pdaSettings.settings.masterID = tonumber(os.getComputerID())
				pdaSettings.thisDevice.type="PDA"
				pdaSettings = textutils.serialize(pdaSettings)
				if fs.exists(path.."/remoteControlPDA") then fs.delete(path.."/remoteControlPDA") end
				local f = fs.open(path..'/remoteControlPDA', 'w')
				f.write(pdaSettings)
				f.close()
				--Place a settings file in the PDA containing the ID of the master PC and the type of device it is.
				disk.eject(side)
			end
		elseif event == 'key' then
		if side == keys.leftAlt or side == keys.rightAlt then changePage('settings') return end
		end
	end
end

function tableClear()
	tablesToRemove = {displayButtons, elements}
	for i, v in ipairs (tablesToRemove) do
		local k = next(v)
		while k do
			v[k] = nil
			k = next(v)
		end
	end
end

function viewClients()
	changePage("clientList")
	displayButtons = {}
	buttonBlacklist = {""}
	local function clientList()
		local title = "Choose the device you want to manage"
        local tArgs = current.devices.Client
		if #tArgs < 1 then
			drawTitleBar()
			printer.centered("You Haven't Registered Any Clients!", 6)
			printer.centered("Register Some First", 7)
			printer.centered("Click To Return", 18)
			os.pullEvent("mouse_click")
			return
		end
        local pages = {[1]={}}
        for i = 1, #tArgs, 1 do
                if #pages[ #pages ] == 6 then
                        pages[ #pages + 1 ] = {}
                end
                pages[ #pages ][ #pages[#pages] + 1 ] = tArgs[ i ]
        end
        local maxLen = 0
        for k, v in ipairs( tArgs ) do
                if #v > maxLen then maxLen = #v maxLenChar = k end
        end
        local maxx, maxy = term.getSize()
        if maxLen > maxx - 20 then
                error('String In The Array Is Too LARGE To Display, We Removed: '..maxLenChar)
        end
        local page = 1
        local selected = 1
        local function render()
                local tbl = pages[ page ]
                printer.centered(title, 4)
				local xValue = 2
				local Count = 1
				local yValue = 8
				tableClear()
				LogFile.i("Length Of PreRender: "..tostring(#tbl), runningProgram)
				if pages[page-1] then prevBtn = btnInit("Previous Page", nil, nil, 2, 18, 1, colors.cyan, 1, 256, function() os.queueEvent("PreviousPage") end, false, nil, nil, nil, nil) end
				if pages[page+1] then nxtBtn = btnInit("Next Page", nil, nil, termX - 2 - #"Next Page", 18, 1, colors.cyan, 1, 256, function() os.queueEvent("NextPage") end, false, nil, nil, nil, nil) end
				backBtn = btnInit("Return", nil, nil, termX/2-#"Return"/2, 18, 1, colors.red, 1, 256, function() os.queueEvent("back") end, false, nil, nil, nil, nil)
                for i = 1, #tbl do
					if Count == 1 then x = 2 y = 8
					elseif Count == 2 then y = 8 x = termX-4-#"Manage Client"-#tbl[i]
					elseif Count == 3 then y = 11 x = 2
					elseif Count == 4 then y = 11 x = termX-4-#"Manage Client"-#tbl[i]
					elseif Count == 5 then y = 14 x = 2
					elseif Count == 6 then y = 14 x = termX-4-#"Manage Client"-#tbl[i] Count = 1
					end
                    displayButtons[tbl[i]] = btnInit("Manage Client "..tbl[i], nil, nil, x, y, 1, colors.cyan, 1, 256, function() action(tbl[i]) end, false, nil, nil, nil, nil)
					Count = Count + 1
                end
                if pages[ page - 1 ] then
                    element.opacity(prevBtn, true)
                end
                if pages[ page + 1 ] then
                    element.opacity(nxtBtn, true)
                end
                local str = "(" .. page .. "/" .. #pages .. ")"
                printer.centered( str , 19)
        end
        while true do
			render()
			local event, param1, p2, p3 = os.pullEvent()
			if event == "mouse_click" then
				checkClick(event, param1, p2, p3)
			elseif event == "PreviousPage" then
				if pages[page-1] then
					drawTitleBar()
					printer.centered("Loading, Please Wait...", 4) sleep(0)
					page = page -1
					hideElement("-a")
					element.opacity(prevBtn, false)
					element.opacity(nxtBtn, false)
					tableClear()
					drawTitleBar()
				else 
					prevBtn.visible = false 
					LogFile.w("Previous Button Fired When On First Page!", runningProgram) 
				end
			elseif event == "NextPage" then
				if pages[page+1] then
					drawTitleBar()
					printer.centered("Loading, Please Wait...", 4) sleep(0.2)
					page = page + 1
					element.opacity(prevBtn, false)
					element.opacity(nxtBtn, false)
					tableClear()
					drawTitleBar()
				else 
					nxtBtn.visible = false 
					LogFile.w("Next Button Fired When On Last Page!", runningProgram) 
				end
			elseif event == "back" then
				changePage('main')
				return
			end
        end
	end
	clientList()
	changePage("main")
end

function action(ID)
	local function refreshSide(side, msg)
		if not pocket then
			printer.centered('Loading...', 4)
			rawrequest = {}
			rawrequest["name"] = "RedstoneState"
			rawrequest["side"] = side
			request = textutils.serialize(rawrequest)
			rednet.send(tonumber(ID), request, 'TABLEREQUEST')
			local id, msg, proto = rednet.receive(3)
			printer.centered('Redstone Settings For Client '..ID, 6)
			if id == tonumber(ID) and msg and proto == "requestResponse" then
				
			else
				changePage('No')
				if pocket then 
					printer.centered('The Client Didnt Complete', 6)
					printer.centered("The Task!", 7)
				else
					printer.centered('The Client Did\'nt Complete The Task', 6)
					printer.centered('It may be busy, otherwise try again', 8)
				end
				printer.centered('Click To Return', 19)
				os.pullEvent('mouse_click')
				return 'err'
			end
			printer.centered('', 4)
			if msg == "false" then printer.centered('The '..side..' Side Is Not Currently Emitting Redstone', 8) elseif msg == "true" then printer.centered('The '..side..' Side Is Currently Emitting Redstone', 8) else printer.centered('The '..side..'Is Unknown (Check Connectivity)', 8) end
		end
	end

	
	local function RST(ID)
		changePage('actionRST')
		local state = refreshSide(redstoneSide)
		if state == 'err' then changePage('action') return end
		while true do
			if pocket then printer.centered('Redstone Client '..ID, 6) end
			local e, p1, p2, p3 = os.pullEvent()
			if e == 'back' then changePage('action') return
			elseif e == "changeSide" then 
			local state = refreshSide(redstoneSide)
			if state == 'err' then changePage('action') return end
			elseif e == "next" then 
			elseif e == "mouse_click" then checkClick(e, p1, p2, p3)
			elseif e == "send" then
				if rsToggleState.toggleState == 1 then redstoneState = true else redstoneState = false end
				changePage('RDsubmit')
				printer.centered('Creating Request', 6)
				rrequest = {}
				rrequest["name"] = "redstonePerm"
				rrequest["side"] = redstoneSide
				rrequest["state"] = redstoneState
				rrequest["forwardID"] = ID
				request = textutils.serialize(rrequest)
				if pocket then
					rednet.send(current.settings.masterID, request, 'forwardTaskRequest')
					printer.centered('Task Complete', 6)				
					printer.centered('Click Anywhere To Return', 18)
					os.pullEvent('mouse_click')
					changePage('action')
					return
				else
					rednet.send(tonumber(ID), request, 'taskRequest')
					printer.centered('Request Sent', 6)
					printer.centered('Waiting For Response', 6)
					local m, m2 = rednet.receive(3)
					if m == tonumber(ID) and m2 == "Complete" then
						printer.centered('Task Complete', 6)				
						printer.centered('Click Anywhere To Return', 18)
						os.pullEvent('mouse_click')
						changePage('action')
						return
					else
						changePage('No')
						if pocket then 
							printer.centered('The Client Didnt Complete', 6)
							printer.centered("The Task!", 7)
						else
							printer.centered('The Client Did\'nt Complete The Task', 6)
							printer.centered('It may be busy, otherwise try again', 8)
						end
						printer.centered('Click To Return', 19)
						os.pullEvent('mouse_click')
						changePage('action')
					end
				end
			end
		end
	end
	
	local function RSP(ID)
		while true do
			changePage('actionRSP')
			printer.centered('Pulse Client '..ID, 6)
			printer.centered('Side And Time', 7)
			printer.centered('Client Wont Respond', 15)
			local text = 'Time: '
			term.setCursorPos(termX/2-#text+5, 14)
			write(text)
			local input = uInput.eventN(2, nil, elements)
			local e, p1, p2, p3 = os.pullEvent()
			if e == "mouse_click" then checkClick(e, p1, p2, p3)
			elseif e == "send" then 
				if input ~= "" then
					changePage('RDsubmit')
					printer.centered('Creating Request', 6)
					--Create Request
					rrequest = {}
					rrequest["name"] = "redstonePulse"
					rrequest["side"] = redstoneSide
					rrequest["time"] = input
					rrequest["forwardID"] = ID
					request = textutils.serialize(rrequest)
					if pocket then
						rednet.send(current.settings.masterID, request, 'forwardTaskRequest')
						printer.centered('Task Complete', 6)				
						printer.centered('Click Anywhere To Return', 18)
						os.pullEvent('mouse_click')
						changePage('action')
						return
					else
						rednet.send(tonumber(ID), request, 'taskRequest')
						printer.centered('Request Sent', 6)
						printer.centered('Waiting For Response', 6)
						local m, m2 = rednet.receive(3)
						if m == tonumber(ID) and m2 == "Complete" then
							printer.centered('Task Complete', 6)				
							printer.centered('Click Anywhere To Return', 18)
							os.pullEvent('mouse_click')
							changePage('action')
							return
						else
							changePage('No')
							if pocket then 
								printer.centered('The Client Didnt Complete', 6)
								printer.centered("The Task!", 7)
							else
								printer.centered('The Client Did\'nt Complete The Task', 6)
								printer.centered('It may be busy, otherwise try again', 8)
							end
							printer.centered('Click To Return', 19)
							os.pullEvent('mouse_click')
							changePage('action')
						end
					end
				else
					printer.centered('Enter A Time To Pulse For', 19)
					sleep(1)
				end
			elseif e == "back" then
				term.setCursorBlink(false)
				changePage('action')
				return
			end
		end
		
	end
	
	local function OSopt(ID)
		changePage('actionOSopt')
		while true do
			if pocket then printer.centered('CraftOS Client '..ID, 6) else printer.centered('CraftOS Options For Client '..ID, 6) end
			local e, p1, p2, p3 = os.pullEvent()
			if e == "mouse_click" then checkClick(e, p1, p2, p3)
			elseif e == "goback" then changePage('action') return
			elseif e == "sd" then
				rrequest = {}
				rrequest["name"] = "sysOp"
				rrequest["osOpt"] = "shutdown"
				if pocket then rrequest["forwardID"] = ID end
				os.queueEvent('send')
				--Send shutdown message
			elseif e == "rb" then
				rrequest = {}
				rrequest["name"] = "sysOp"
				rrequest["osOpt"] = "reboot"
				if pocket then rrequest["forwardID"] = ID end
				os.queueEvent('send')
				--Send reboot message
			elseif e == "send" then
				changePage('RDsubmit')
				printer.centered('Creating Request', 6)
				request = textutils.serialize(rrequest)
				if pocket then
					rednet.send(tonumber(current.settings.masterID), request, 'forwardTaskRequest')
				else
					rednet.send(tonumber(ID), request, 'taskRequest')
				end
				printer.centered('Request Sent', 6)
				printer.centered('Task Complete', 6)				
				printer.centered('Click Anywhere To Return', 18)
				os.pullEvent('mouse_click')
				changePage('action')
				return
			end
		end
	end
	
	if pocket then
	tableClear()
	drawTitleBar()
	rednet.send(current.settings.masterID, ID, 'pingClient')
	printer.centered('Pinging Client: '..ID, 6)
	local id, msg = rednet.receive(5)
	if tonumber(id) ~= tonumber(current.settings.masterID) or msg ~= "true" then
		printer.centered('Client isnt responding', 6)
		printer.centered('Is it within range?', 8)
		printer.centered('Click Anywhere To return', 19)
		os.pullEvent('mouse_click')
		changePage('clientList')
		return
	end
	else
	tableClear()
	drawTitleBar()
	printer.centered('Pinging Client: '..ID, 6)
	rednet.send(tonumber(ID), "Ping")
	local id, msg = rednet.receive(3)
	if tonumber(id) ~= tonumber(ID) or msg ~= "Pong" then
		printer.centered('The client is not responding!', 6)
		printer.centered('Make sure it is within range', 8)
		printer.centered('Click Anywhere To return', 19)
		os.pullEvent('mouse_click')
		changePage('clientList')
		return
	end
	end
	while true do		
		changePage('action')
		printer.centered("Managing Client: "..ID, 6)
		local e, p1, p2, p3 = os.pullEvent()
		if e == "mouse_click" then doClick(e, p1, p2, p3)
		elseif e == "RedstoneToggle" then RST(ID)
		elseif e == "RedstonePulse" then RSP(ID)
		elseif e == "OSop" then OSopt(ID)
		elseif e == "back" then changePage('clientList') return end
	end
	
end

function setup()
	local function setupTitleBar()
		titleBar.draw('HbombOS Secuity Suite', 'Remote Control Setup', colors.cyan, 256, 128, 256, 1)
	end
	
	local function modemready()
		while not modem.isPresent() do
			setupTitleBar()
			printer.centered("Attach A Wireless Modem To Continue", 6)
			os.pullEvent('peripheral')
		end
		LogFile.i("Found Modem", runningProgram)
		modem.Initialise()
	end
	
	local function welcome()
		modemready()
		while true do
			setupTitleBar()
			printer.centered("Welcome, In the next few minutes you'll be", 6)
			printer.centered("setting up Your Remote Control system.", 7)
			printer.centered("Please Note: This program uses rednet to send, ", 9)
			printer.centered("messages, ensure your clients are in rednet range", 10)
			printer.centered("and that they have rednet modems attached", 11)
			start = btnInit("Lets Go!", nil, nil, termX-3-#"Lets Go!", 18, 1, colors.green, 1, 256, function() os.queueEvent("next") end, false, nil, nil, nil, nil)
			e, p1, p2, p3 = os.pullEvent()
			if e == "mouse_click" then checkClick(e, p1, p2, p3) elseif e == "next" then tableClear() break end
		end
	end
	
	local function pickDevice()
		setupTitleBar()
		c = btnInit('Client', nil, 3, 2, 16, 1, colors.cyan, 1, 256, function() deviceChosen="client" end, true, colors.green, 1, 'Client', 'dChose')
		element.toggle(c)
		deviceChosen = "client" --Default
		ms = btnInit('Master', nil, 3, termX-2-#"Master", 16, 1, colors.cyan, 1, 256, function() deviceChosen="master" end, true, colors.green, 1, 'Master', 'dChose')
		start = btnInit("Next", nil, nil, termX/2-#"Next"/2, 18, 1, colors.green, 1, 256, function() os.queueEvent("Continue") end, false, nil, nil, nil, nil)
		while true do
			printer.centered("This program allows superior control over your base", 6)
			printer.centered("in Minecraft, using the help of other PCs", 7)
			printer.centered("Please pick what PC this is below;", 8)
			printer.centered("A client is something that receives", 10)
			printer.centered("instructions from the master, the master", 11)
			printer.centered("is what you control, commanding clients to do stuff!", 12)
			e, p1, p2, p3 = os.pullEvent()
			if e == "mouse_click" then checkClick(e, p1, p2, p3) 
			elseif e == "Continue" then tableClear() drawTitleBar() break end
		end
	end
	welcome()
	pickDevice()
	if deviceChosen == "client" then
		local function welcome()
			setupTitleBar()
			printer.centered("Setting Up Client PC", 6)
			printer.centered("First, you'll need to know the basics;", 7)
			printer.centered("The Computers ID is: "..tostring(os.getComputerID()).." IMPORTANT", 8)
			start = btnInit("Next", nil, nil, termX/2-#"Next"/2, 18, 1, colors.green, 1, 256, function() os.queueEvent("Continue") end, false, nil, nil, nil, nil)
			while true do
				e, p1, p2, p3 = os.pullEvent()
				if e == "mouse_click" then checkClick(e, p1, p2, p3) 
				elseif e == "Continue" then tableClear() drawTitleBar() break end
			end
		end
		
		local function about()
			setupTitleBar()
			printer.centered("The client receives messages from the master" , 6)
			printer.centered("and often responds with its status", 7)
			start = btnInit("Next", nil, nil, termX/2-#"Next"/2, 18, 1, colors.green, 1, 256, function() os.queueEvent("Continue") end, false, nil, nil, nil, nil)
			while true do
				e, p1, p2, p3 = os.pullEvent()
				if e == "mouse_click" then checkClick(e, p1, p2, p3) 
				elseif e == "Continue" then tableClear() drawTitleBar() break end
			end
		end
		
		
		local function register()
			setupTitleBar()
			printer.centered("because this program talks to other PCs", 6)
			printer.centered("You will need to have another computer running", 7)
			printer.centered("this program, it will need to be set up as a master", 8)
			printer.centered("you can only have one master in a client",9 )
			printer.centered("click next to register one now", 10)
			tableClear()
			reg = btnInit("Register Now", nil, nil, 2, 18, 1, colors.green, 1, 256, function() os.queueEvent("register") end, false, nil, nil, nil, nil)
			while true do
				e, p1, p2, p3 = os.pullEvent()
				if e == "mouse_click" then checkClick(e, p1, p2, p3) 
				elseif e == "register" then tableClear() break end
			end
		end
		
		local function masterReg()
			while true do
				setupTitleBar()
				tableClear()
				nextBtn = btnInit("Confirm", nil, nil, termX-4-#"Confirm", 18, 1, colors.green, 1, 256, function() os.queueEvent("submit_Result") end, false, nil, nil, nil, nil)
				printer.centered("Enter the ID of the master computer below", 6)
				printer.centered("click \"Confirm\" when your done!", 7)
				term.setCursorPos(termX/2-#"Master ID: ", 10)
				write"Master ID: "
				local input = uInput.eventN(5, nil, elements)
				if input ~= "" and input ~= tostring(os.getComputerID()) then
					printer.centered("Please Wait While We Ping That ID ("..input..")", 19)
					input = tonumber(input)
					rednet.send(tonumber(input), "Ping")
					local sender, message, protocol = rednet.receive(5)
					sender = sender or ""
					message = message or ""
					if tostring(sender) == tostring(input) and message == "Pong" then
						printer.centered("Master Computer Response Found", 19)
						sleep(2)
						tableClear()
						current.settings.masterID = input
						break
					else
						setupTitleBar()
						printer.centered("We did not get a response!", 6)
						printer.centered("Ensure the master computer is on-line and retry", 10)
						printer.centered("Click Anywhere To Continue", 19)
						os.pullEvent("mouse_click")
					end
				elseif input == "" then
					printer.centered("Please Enter An ID!", 19)
					sleep(0.5)
				elseif input == tostring(os.getComputerID()) then
					printer.centered("Enter the master PCs ID, Not Yours!", 19)
					sleep(0.5)
				end
			end
			setupTitleBar()
			printer.centered("To finish registration please go to your master PC", 6)
			printer.centered("and use your settings page to register this as a client", 7)
			printer.centered("We don't do this here for security reasons.", 8)
			printer.centered("Click Anywhere to Finish", 19)
			os.pullEvent("mouse_click")
		end
		
		local function saving()
			setupTitleBar()
			printer.centered("You have completed set-up... we haven't", 6)
			printer.centered("Sit tight while we finish up", 7)
			local function save()
				current.thisDevice.type = "CLIENT"
				current.thisDevice.ID = tostring(os.getComputerID())
				current.thisDevice.Name = os.getComputerLabel()
				sleep(4)
				SaveSettings()
				sleep(0.6)
				sleep(1)
				os.reboot()
			end
			parallel.waitForAny(save, loadingIcon)
		end
		welcome()
		about()
		register()
		masterReg()
		saving()
		
	elseif deviceChosen == "master" then
		
		local function welcome()
			setupTitleBar()
			printer.centered("Setting Up Master PC", 6)
			printer.centered("First, you'll need to know the basics;", 7)
			printer.centered("The Computers ID is: "..tostring(os.getComputerID()).." IMPORTANT", 8)
			start = btnInit("Next", nil, nil, termX/2-#"Next"/2, 18, 1, colors.green, 1, 256, function() os.queueEvent("Continue") end, false, nil, nil, nil, nil)
			while true do
				e, p1, p2, p3 = os.pullEvent()
				if e == "mouse_click" then checkClick(e, p1, p2, p3) 
				elseif e == "Continue" then tableClear() drawTitleBar() break end
			end
		end
		
		local function about()
			setupTitleBar()
			printer.centered("The master client sends messages to client" , 6)
			printer.centered("computers, these messages are tables", 7)
			printer.centered("full of the information You choose to send", 8)
			printer.centered("After a client is registered it will be added to the", 10)
			printer.centered("list. You can then click then the button with", 11)
			printer.centered("the clients ID. You can then choose a request to", 12)
			printer.centered("submit to the client. You cannot save a function, ", 13)
			printer.centered("this may come in the future release...", 14)
			start = btnInit("Next", nil, nil, termX/2-#"Next"/2, 18, 1, colors.green, 1, 256, function() os.queueEvent("Continue") end, false, nil, nil, nil, nil)
			while true do
				e, p1, p2, p3 = os.pullEvent()
				if e == "mouse_click" then checkClick(e, p1, p2, p3) 
				elseif e == "Continue" then tableClear() drawTitleBar() break end
			end
		end
		
		local function register()
			setupTitleBar()
			printer.centered("because this program talks to other PCs", 6)
			printer.centered("You will need to have other computers running", 7)
			printer.centered("this program, they will need to be set up as clients", 8)
			printer.centered("click next to start entering the IDs of clients",9 )
			printer.centered("you want to control, otherwise click skip to do it later", 10)
			tableClear()
			skip = btnInit("Skip", nil, nil, termX-2-#"Next"/2, 18, 1, colors.green, 1, 256, function() os.queueEvent("Skip") end, false, nil, nil, nil, nil)
			reg = btnInit("Register Now", nil, nil, 2, 18, 1, colors.green, 1, 256, function() os.queueEvent("register") end, false, nil, nil, nil, nil)
			while true do
				e, p1, p2, p3 = os.pullEvent()
				if e == "mouse_click" then checkClick(e, p1, p2, p3) 
				elseif e == "Skip" then tableClear() drawTitleBar() break elseif e == "register" then tableClear() registerClient(true) end
			end
		end
		
		local function saving()
			setupTitleBar()
			printer.centered("You have completed setup... we haven't", 6)
			printer.centered("Please wait while we gather information", 7)
			printer.centered("about this system, this is used by your clients", 8)
			printer.centered("to make sure it is the correct master PC", 9)
			
			local function save()
				current.thisDevice.type = "MASTER"
				current.thisDevice.ID = tostring(os.getComputerID())
				current.thisDevice.Name = os.getComputerLabel()
				sleep(4)
				SaveSettings()
				sleep(0.6)
				sleep(1)
				os.reboot()
			end
			parallel.waitForAny(save, loadingIcon)
		end
		welcome()
		about()
		register()
		saving()
	end
end

function settings()
	changePage("settings")
	while true do
		e, p1, p2, p3 = os.pullEvent()
		if e == "mouse_click" then
			doClick(e, p1, p2, p3)
		elseif e == "goback" then
			tableClear()
			changePage('main')
			sleep(0)
			return
		end
	end
end

function registerClient(noBack)
	tableClear()
	local function connection()
		while true do
			tableClear()
			drawTitleBar()
			connectBtn = btnInit("Connect", nil, nil, termX-4-#"Connect", 18, 1, colors.green, 1, 256, function() os.queueEvent("submit_Result") end, false, nil, nil, nil, nil)
			if not noBack then returnBtn = btnInit("Return", nil, nil, 2, 18, 1, colors.red, 1, 256, function() os.queueEvent("back") end, false, nil, nil, nil, nil) end
			printer.centered("To Register A Client Type Its ID Below", 6)
			printer.centered("Then Click \"Connect\" To Test The Connection", 8)
			local text = "Client ID: "
			term.setCursorPos(termX/2-#text, 12)
			write(text)
			local input = uInput.eventN(5, nil, elements)
			if input ~= "" and input ~= tostring(os.getComputerID()) then
				LogFile.i("Trying To Ping ID: "..input, runningProgram)
				for i=1, 3 do
					printer.centered("Connecting..."..i, 19)
					LogFile.i("Attempt "..tostring(i), runningProgram)
					rednet.send(tonumber(input), "Ping")
					local ID, MSG = rednet.receive(3)
					ID = tonumber(ID) or ""
					MSG = MSG or "" 
					if ID == tonumber(input) and MSG == "Pong" then
						printer.centered("Pong Received, Connected.", 19) sleep(1)
						for i, v in ipairs(current.devices.Client) do
							if tonumber(v) == tonumber(input) then
								printer.centered("You Have Already Registered This Client", 19)
								sleep(1)
								return
							end
						end
						table.insert(current.devices.Client, input)
						printer.centered("ID Added To List, Use Client List To Control!", 19)
						SaveSettings()
						sleep(1)
						return
					else
						if i == 3 then printer.centered("Could Not Establish A Connection!", 19) sleep(1) end
					end
				end
			elseif input == tostring(os.getComputerID()) then
				printer.centered("Enter A Client ID, Not Your Own", 19)
				sleep(0.5)
			elseif input == "" then
				printer.centered("Enter An ID!", 19)
				sleep(0.5)
			else
				printer.centered("An Unknown Error Occurred", 19) sleep(1)
			end
		end
	end
	
	local function eventListen()
		while true do
			local event, p1, p2, p3 = os.pullEvent()
			if event == "mouse_click" then
				doClick(event, p1, p2, p3)
			elseif event == "back" then
				break
			end
		end
	end
	
	parallel.waitForAny(eventListen, connection)
	return
end

function unregisterClient()
	tableClear()
	local function connection()
		while true do
			tableClear()
			drawTitleBar()
			connectBtn = btnInit("Connect", nil, nil, termX-4-#"Connect", 18, 1, colors.green, 1, 256, function() os.queueEvent("submit_Result") end, false, nil, nil, nil, nil)
			returnBtn = btnInit("Return", nil, nil, 2, 18, 1, colors.red, 1, 256, function() os.queueEvent("back") end, false, nil, nil, nil, nil)
			printer.centered("To Remove A Client Type Its ID Below", 6)
			printer.centered("Then Click \"Remove\" To Delete The Connection", 8)
			local text = "Client ID: "
			term.setCursorPos(termX/2-#text, 12)
			write(text)
			local input = uInput.eventN(5, nil, elements)
			if input ~= "" and input ~= tostring(os.getComputerID()) then
				printer.centered('Checking Database', 19)
				for i, v in ipairs(current.devices.Client) do
					if tonumber(v) == tonumber(input) then
						table.remove(current.devices.Client, i)
						SaveSettings()
						printer.centered("Client Removed", 19)
						sleep(1)
						return
					end
				end
			elseif input == tostring(os.getComputerID()) then
				printer.centered("Enter A Client ID, Not Your Own", 19)
				sleep(0.5)
			elseif #current.devices.Client < 1 then
				printer.centered('You Dont Have Any Clients!', 19)
				sleep(1)
			elseif input == "" then
				printer.centered("Enter An ID!", 19)
				sleep(0.5)
			else
				printer.centered("An Unknown Error Occurred", 19) sleep(1)
			end
		end
	end
	
	local function eventListen()
		while true do
			local event, p1, p2, p3 = os.pullEvent()
			if event == "mouse_click" then
				doClick(event, p1, p2, p3)
			elseif event == "back" then
				break
			end
		end
	end
	
	parallel.waitForAny(eventListen, connection)
	return
end

function loadSettings()
  LogFile.i('Loading Settings', runningProgram)
  if fs.exists('systemFiles/Programs/remoteControlSettings') then
		local f = fs.open('systemFiles/Programs/remoteControlSettings', 'r')
		if f then
			current = textutils.unserialize(f.readAll())
			LogFile.i('Settings Loaded', runningProgram)
		end
		f.close()
	else
		setup()
	end
end

function SaveSettings()
    LogFile.i('Saving Settings', runningProgram)
	current = current or {}
	local f = fs.open('systemFiles/Programs/remoteControlSettings', 'w')
	if f then
		f.write(textutils.serialize(current))	    
		LogFile.i('Settings Saved', runningProgram)
	end
	f.close()	
end

function messageHandler()
	LogFile.i("Message Handler ONLINE!", runningProgram)
	while true do
		sleep(0)
		local messageSender, message, messageProtocol = rednet.receive()
		messageProtocol = messageProtocol or ""
		LogFile.i("Message Received: "..messageSender.." : "..message.." : "..messageProtocol, runningProgram)
		--If we get a message then the response will change depending on the type of client.
		
		if current.thisDevice.type == "MASTER" then
			if message == "Ping" then --This may be a new client, respond with pong
				rednet.send(tonumber(messageSender), "Pong")
			elseif message == "AmIYours" then
				LogFile.i('Am I yours request!', runningProgram)
				for i, v in ipairs(current.devices.Client) do
					if tonumber(messageSender) == tonumber(v) then
						rednet.send(messageSender, 'true')
						foundD = true
					end
				end
				if not foundD then rednet.send(messageSender, 'false') elseif foundD then foundD = false end
			elseif message == "requestClients" then
				LogFile.i('Client List Requested', runningProgram)
				rednet.send(messageSender, current.devices.Client)
			elseif messageProtocol == 'pingClient' then
				rednet.send(tonumber(message), 'Ping')
				local m, m2, m3 = rednet.receive(2)
				if m == tonumber(message) and m2 == "Pong" then
					rednet.send(messageSender, 'true')
				else
					rednet.send(messageSender, 'false')
				end
			elseif messageProtocol == 'forwardTaskRequest' then
				LogFile.i('Forward Message Received', runningProgram)
				--Request from PDA to forward to client in message
				local rawMessage = textutils.unserialize(message)
				rednet.send(tonumber(rawMessage["forwardID"]), message, 'taskRequest')
			end
		elseif current.thisDevice.type == "CLIENT" then
			if message == "Ping" and messageSender == current.settings.masterID then
				--Ping is from master
				rednet.send(current.settings.masterID, "Pong")
			elseif messageProtocol == "taskRequest" and messageSender == current.settings.masterID then
				--This is a table containing the task I need to do
				local task = textutils.unserialize(message)
				if task["name"] == "redstonePerm" then
					rs.setOutput(task["side"], task["state"])
					rednet.send(current.settings.masterID, "Complete")
				elseif task["name"] == "redstonePulse" then
					rs.setOutput(task["side"], true)
					rednet.send(current.settings.masterID, "Complete")
					sleep(tonumber(task["time"]))
					rs.setOutput(task["side"], false)
				elseif task["name"] == "sysOp" then
					if task["osOpt"] == "shutdown" then
						os.shutdown()
					elseif task["osOpt"] == "reboot" then
						os.reboot()
					end
				end
			elseif messageProtocol == 'TABLEREQUEST' and messageSender == current.settings.masterID then
				request = textutils.unserialize(message)
				if request["name"] == "RedstoneState" then
					rednet.send(tonumber(messageSender), tostring(rs.getOutput(request["side"])), 'requestResponse')
				end
			end
		end
	end
	LogFile.e("Message Handler OFFLINE", runningProgram)
end

function pocketStart()
	modem.Initialise()
	termX, termY = term.getSize()
	--Pocket computers function alot differently, they require a startup function different to that other normal computers
	--Load important APIs
	term.clear()
	print('Please Wait, Loading APIs')
	
	local apis = {
		"titleBar",
		"element",
		"LogFile",
		"printer",
		"uInput",
	}	
	for _, v in ipairs(apis) do
		sleep(0)
		if not os.loadAPI('/api/'..v) then error('An error occurred when loading pocket APIs') end
	end
	LogFile.Initialise()
	pocketPC.loadSettings()
	notOn = true
	--Ping master computer
	while notOn do
		for i=1, 3 do
			drawTitleBar()
			printer.centered("Pinging Master Computer", 6)
			printer.centered("Sending Ping", 7)
			rednet.send(current.settings.masterID, "Ping")
			printer.centered("Waiting For Response..."..i, 7)
			local messageID, Message = rednet.receive(5)
			messageID = messageID or ""
			Message = Message or ""
			if Message == "Pong" and messageID == current.settings.masterID then
				notOn = false
				break
			elseif Message ~= "Pong" and messageID ~= current.settings.masterID and i == 3 then
				error(messageID.." :: "..Message)
				drawTitleBar()
				printer.centered("Cannot Connect To Master", 6)
				printer.centered("Is It Within Range", 8)
				printer.centered("And Is On-line!", 9)
				printer.centered("Click Anywhere To Retry", 19)
				os.pullEvent("mouse_click")
			end
		end
	end
	printer.centered('', 7)
	sleep(0)
	printer.centered('Retrieiving From Master', 6)
	-- Get all settings and client lists etc... from master
	current.devices = {}
	current.devices.masterClients ={}
	current.devices.masterClients = pocketPC.retrieveClients(current.settings.masterID)
	if #current.devices.masterClients < 1 then
		drawTitleBar()
		printer.centered('No Clients Found', 6)
		printer.centered('Register Some On Master', 8)
		sleep(3)
		os.shutdown()
	else
		drawTitleBar()
		printer.centered('Clients Found! ('..#current.devices.masterClients..')', 6)
		sleep(0.5)
		pocketPC.saveSettings()
		drawTitleBar()
		pocketPC.viewClients()
	end
end

pocketPC = {
	ping = function(ID)
		rednet.send(ID, 'Ping')
		local m, m1, m2 = rednet.receive(3)
		m = m or ""
		m1 = m1 or ""
		m2 = m2 or ""
		if tonumber(m) == ID and m1 == "Pong" then
			return true
		end
		return false
	end,

	retrieveClients = function(ID)
		rednet.send(ID, "requestClients")
		local m, m1,m2 = rednet.receive(3)
		if m == current.settings.masterID then
			return m1
		end
		return {}
	end,
	
	loadSettings = function()
		if fs.exists('remoteControlPDA') then
			local f = fs.open('remoteControlPDA', 'r')
			if f then
				current = textutils.unserialize(f.readAll())
				LogFile.i('Settings Loaded', runningProgram)
			end
			f.close()
		else
			error'The Sync Did Not Bring Across Compatible Settings, Please Resync With The Master PC'
		end
	end,
	
	saveSettings = function()
		current = current or {}
		local f = fs.open('remoteControlPDA', 'w')
		if f then
			f.write(textutils.serialize(current))	    
		end
		f.close()	
	end,
	
	viewClients = function()
		local title = "Client List"
        local tArgs = current.devices.masterClients
        local pages = {[1]={}}
        for i = 1, #tArgs, 1 do
                if #pages[ #pages ] == 6 then
                        pages[ #pages + 1 ] = {}
                end
                pages[ #pages ][ #pages[#pages] + 1 ] = tArgs[ i ]
        end
        local maxLen = 0
        for k, v in ipairs( tArgs ) do
                if #v > maxLen then maxLen = #v maxLenChar = k end
        end
		local termX, termY = term.getSize()
        local maxx, maxy = term.getSize()
        if maxLen > maxx - 20 then
                error('String In The Array Is Too LARGE To Display, We Removed: '..maxLenChar)
        end
        local page = 1
        local selected = 1
        local function render()
                local tbl = pages[ page ]
                printer.centered(title, 4)
				local xValue = 2
				local Count = 1
				local yValue = 8
				tableClear()
				if pages[page-1] then prevBtn = btnInit("Prev", nil, nil, 2, 20, 1, colors.cyan, 1, 256, function() os.queueEvent("PreviousPage") end, false, nil, nil, nil, nil) end
				if pages[page+1] then nxtBtn = btnInit("Next", nil, nil, termX-2-#"Next", 20, 1, colors.cyan, 1, 256, function() os.queueEvent("NextPage") end, false, nil, nil, nil, nil) end
                for i = 1, #tbl do
					if Count == 1 then x = 2 y = 6
					elseif Count == 2 then y = 8 x = 2
					elseif Count == 3 then y = 10 x = 2
					elseif Count == 4 then y = 12 x = 2
					elseif Count == 5 then y = 14 x = 2
					elseif Count == 6 then y = 16 x = 2
					end
                    displayButtons[tbl[i]] = btnInit("Client "..tbl[i], nil, nil, x, y, 1, colors.cyan, 1, 256, function() action(tbl[i]) end, false, nil, nil, nil, nil)
					Count = Count + 1
                end
                if pages[ page - 1 ] then
                    element.opacity(prevBtn, true)
                end
                if pages[ page + 1 ] then
                    element.opacity(nxtBtn, true)
                end
                local str = "(" .. page .. "/" .. #pages .. ")"
                printer.centered( str , 19)
        end
        while true do
			render()
			local event, param1, p2, p3 = os.pullEvent()
			if event == "mouse_click" then
				checkClick(event, param1, p2, p3)
			elseif event == "PreviousPage" then
				if pages[page-1] then
					drawTitleBar()
					printer.centered("Loading, Please Wait...", 4) sleep(0)
					page = page -1
					hideElement("-a")
					element.opacity(prevBtn, false)
					element.opacity(nxtBtn, false)
					tableClear()
					drawTitleBar()
				else 
					prevBtn.visible = false 
					LogFile.w("Previous Button Fired When On First Page!", runningProgram) 
				end
			elseif event == "NextPage" then
				if pages[page+1] then
					drawTitleBar()
					printer.centered("Loading, Please Wait...", 4) sleep(0.2)
					page = page + 1
					element.opacity(prevBtn, false)
					element.opacity(nxtBtn, false)
					tableClear()
					drawTitleBar()
				else 
					nxtBtn.visible = false 
					LogFile.w("Next Button Fired When On Last Page!", runningProgram) 
				end
			elseif event == "back" then
				changePage('main')
				return
			end
        end
	end
}

function Initialise()
	if pocket then pocketStart() else
	drawTitleBar()
	printer.centered("Loading Your Settings", 6)
	loadSettings()
	tableClear()
	printer.centered("Registering Events", 6)
	sleep(0.4)
	eventRegister('terminate', function(self) errora.err("Termination Detected", "You terminated the program!", true, false) end)
	eventRegister('timer', timerHandler)
	eventRegister('peripheral', checkPeripherals)
	eventRegister('peripheral_detach', checkPeripherals)
	eventRegister('mouse_click', checkClick)
	printer.centered("Initialising Modems", 6)
	while not modem.isPresent() do
		printer.centered("This program uses rednet to communicate between", 6)
		printer.centered("other computers. We cannot detect a wireless modem", 7)
		if not pocket then printer.centered("on this PC please attach one to continue.", 8)
		printer.centered("Well Check When You Attach A Peripheral", 19) else printer.centered('Craft one onto this PDA then reboot', 8) end
		os.pullEvent()
		sleep(0)
	end
	drawTitleBar()
	modem.Initialise()
	notOn = true
	while current.thisDevice.type == "CLIENT" and notOn == true do
		for i=1, 3 do
			drawTitleBar()
			printer.centered("Pinging Master Computer", 6)
			printer.centered("Sending Ping", 7)
			rednet.send(current.settings.masterID, "Ping")
			printer.centered("Waiting For Response..."..i, 7)
			local messageID, Message = rednet.receive(5)
			messageID = messageID or ""
			Message = Message or ""
			if Message == "Pong" and messageID == current.settings.masterID then
				notOn = false
				break
			elseif Message ~= "Pong" and messageID ~= current.settings.masterID and i == 3 then
				drawTitleBar()
				printer.centered("I Cannot Connect To The Master PC", 6)
				printer.centered("Make Sure It Is Within Range Of This PC", 8)
				printer.centered("And Is On-line!", 9)
				printer.centered("Click Anywhere To Retry", 19)
				os.pullEvent("mouse_click")
			end
		end
	end
	printer.centered("Creating Buttons", 6)
	changePage('main')
	parallel.waitForAny(programEventLoop, messageHandler) --Due to modem messages not being sent to an ID but rather a channel I am using the rednet API not the Modem API, This requires a listener to be run using parallel or coroutine rather than the eventRegister.
	end
end

local _, err = pcall(Initialise)
  if err and not pocket then
    term.setCursorBlink(false)
	LogFile.e('XPCALL Error: '..err, runningProgram)
	errora.err(err, 'The Remote Control Program Has Crashed, Error Code Above', true, true)
  elseif err and pocket then
	print ('A fatal error occurred: '..err)
	sleep(5)
	os.shutdown()
  end
--The program appears to have left the loop, Reboot to stop error reporting!
LogFile.e("The Program Appears To Have Left The Loop, To Prevent Error Reporting We Will Reboot", runningProgram)
print'Loop Left!' sleep(1)
os.reboot()