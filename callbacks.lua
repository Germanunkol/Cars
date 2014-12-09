-- This defines all the callbacks needed by server and client.
-- Callbacks are called when certain events happen.
--

-- These are all possible commands clients of the server can send:
CMD = {
	CHAT = 128,
	MAP = 129,
	START_GAME = 130,
	GAMESTATE = 131,
	NEW_CAR = 132,
	MOVE_CAR = 133,
	PLAYER_WINS = 134,
	BACK_TO_LOBBY = 135,
}

function setServerCallbacks( server )
	server.callbacks.received = serverReceived
	server.callbacks.synchronize = synchronize
	server.callbacks.authorize = function( user ) return lobby:authorize( user ) end
	server.callbacks.userFullyConnected = function( user ) lobby:setUserColor( user ) end
end
function setClientCallbacks( client )
	-- set client callbacks:
	client.callbacks.received = clientReceived
	client.callbacks.connected = connected
	client.callbacks.disconnected = disconnected
	-- Called when user is authorized or not (in the second case, a reason is given):
	client.callbacks.authorized = function( auth, reason ) menu:authorized( auth, reason ) end
end

-- Called when client is connected to the server
function connected()
	lobby:show()
end

-- Called when client is disconnected from the server
function disconnected()
	menu:show()
	client = nil
	server = nil
end

-- Called on server when new client is in the process of
-- connecting.
function synchronize( user )
	-- If the server has a map chosen, let the new client know
	-- about it:
	lobby:sendMap( user )
end

function serverReceived( command, msg, user )
	if command == CMD.CHAT then
		-- broadcast chat messages on to all players
		server:send( command, user.playerName .. ": " .. msg )
	elseif command == CMD.MOVE_CAR then
		local x, y = msg:match( "(.*)|(.*)" )
		game:validateCarMovement( user.id, x, y )
	end
end

function clientReceived( command, msg )
	if command == CMD.CHAT then
		chat:newLine( msg )
	elseif command == CMD.MAP then
		lobby:receiveMap( msg )
	elseif command == CMD.START_GAME then
		game:show()
	elseif command == CMD.GAMESTATE then
		game:setState( msg )
	elseif command == CMD.NEW_CAR then
		game:newCar( msg )
	elseif command == CMD.MOVE_CAR then
		game:moveCar( msg )
	elseif command == CMD.PLAYER_WINS then
		game:playerWins( msg )
	elseif command == CMD.BACK_TO_LOBBY then
		lobby:show()
	end
end
