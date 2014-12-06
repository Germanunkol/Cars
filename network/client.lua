
local _PATH = (...):match('^(.*)[%.%/][^%.%/]+$') or ''
package.path = package.path .. ";" .. _PATH .. "/?.lua"

local socket = require("socket")

local User = require( "user" )
local CMD = require( "commands" )

local Client = {}
Client.__index = Client

local userList = {}
local numberOfUsers = 0

local partMessage = ""


function Client:new( address, port, playerName )
	local o = {}
	setmetatable( o, self )

	print("Initialising Client...")
	ok, o.conn = pcall(socket.connect, address, port)
	if ok and o.conn then
		o.conn:settimeout(0)
		print("Client connected", o.conn)
	else
		o.conn = nil
		error("Could not connect.")
	end

	o.callbacks = {
		newUser = nil,
		received = nil,
		receivedPlayername = nil,
		connected = nil,
		disconnected = nil,
	}

	userList = {}
	partMessage = ""

	o.clientID = nil
	o.playerName = playerName

	return o
end

function Client:update( dt )
	if self.conn then
		local data, msg, partOfLine = self.conn:receive()
		if data then
			if #partMessage > 0 then
				data = partMessage .. data
				partMessage = ""
			end

			-- First letter stands for the command:
			command, content = string.match(data, "(.)(.*)")
			command = string.byte( command )

			self:received( command, content )
		else
			if msg == "timeout" then	-- only part of the message could be received
				if #partOfLine > 0 then
					partMessage = partMessage .. partOfLine
				end
			elseif msg == "closed" then
				--self.conn:shutdown()
				print("Disconnected.")
				if self.callbacks.disconnected then
					self.callbacks.disconnected()
				end
				self.conn = nil
				return false
			else
				print("Err Received:", msg, data)
			end
		end
		return true
	else	
		return false
	end
end

function Client:received( command, msg )
	print("cl received:", command, msg )
	if command == CMD.NEW_PLAYER then
		local id, playerName = string.match( msg, "(.*)|(.*)" )
		local user = User:new( nil, playerName, id )
		userList[tonumber(id)] = user
		numberOfUsers = numberOfUsers + 1
	elseif command == CMD.PLAYER_LEFT then
		local id = tonumber(msg)
		userList[id] = nil
		numberOfUsers = numberOfUsers - 1
	elseif command == CMD.AUTHORIZED then
		local authed, reason = string.match( msg, "(.*)|(.*)" )
		if authed == "true" then
			self.authorized = true
			print( "Connection authorized by server." )
		else
			print( "Not authorized to join server. Reason: " .. reason )
		end
		-- When authorized, send player name:
		self:send( CMD.PLAYERNAME, self.playerName )
	elseif command == CMD.PLAYERNAME then
		self.playerName = msg
		-- At this point I am fully connected!
		if self.callbacks.connected then
			self.callbacks.connected()
		end
		print( "new playername",  msg )
	elseif self.callbacks.received then
		self.callbacks.received( command, msg )
	end
end

function Client:send( command, msg )
	print("client send:", command, msg)
	self.conn:send( string.char(command) .. msg .. "\n" )
end

function Client:getUsers()
	return userList
end
function Client:getNumUsers()
	return numberOfUsers
end

function Client:close()
	if self.conn then
		--self.conn:shutdown()
		self.conn:close()
		print( "closed.")
	end
end

return Client