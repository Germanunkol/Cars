local game = {
	GAMESTATE = "",
	usersMoved = {},
	newUserPositions = {},
	time = 0,
	maxTime = 0,
	timerEvent = nil,
	roundTime = 10,
}

-- Possible gamestates:
-- "startup": camera should move to start line
-- "move": players are allowed to make their move.
-- "wait": waiting for server or other players, or for animtion

function game:init()
end

function game:show()
	STATE = "Game"
	ui:setActiveScreen( nil )

	map:removeAllCars()

	if server then
		for id, u in pairs( server:getUsers() ) do
			local col = {
				u.customData.red,
				u.customData.green,
				u.customData.blue,
				255
			}

			local x, y = 0, 0
			map:newCar( u.id, 0, 0, col )
			
			server:send( CMD.NEW_CAR, u.id .. "|" .. x .. "|" .. y )

		end
		game:startMovementRound()
	end
end

function game:update( dt )
	map:update( dt )

	-- Timer:
	if self.timerEvent then
		self.time = self.time + dt
		if self.time >= self.maxTime then
			self.timerEvent()
			self.timerEvent = nil
			self.time = 0
		end
	end
end

function game:draw()
	if client then
		map:draw()
		if self.GAMESTATE == "move" then
			map:drawTargetPoints( client:getID() )
		end
		lobby:drawUserList()
	end
end

function game:keypressed( key )
end

function game:mousepressed( x, y, button )
	if button == "l" then
	if client then
		if self.GAMESTATE == "move" then
			-- Turn screen coordinates into grid coordinates:
			local gX, gY = map:screenToGrid( x, y )
			gX = math.floor( gX + 0.5 )
			gY = math.floor( gY + 0.5 )
			if map:clickAtTargetPosition( client:getID(), gX, gY ) then
				self:sendNewCarPosition( gX, gY )
			end
		end
	end
end
end

function game:setState( state )
	self.GAMESTATE = state
	print("Set game state", state)
	if self.GAMESTATE == "move" then
		
	end
end

function game:newCar( msg )
	if not server then
		local id, x, y = msg:match( "(.*)|(.*)|(.*)")
		id = tonumber(id)
		x = tonumber(x)
		y = tonumber(y)
		print("new car?", id, x, y)
		local users = client:getUsers()
		local u = users[id]
		print("user:", u, users[id])
		if u then
			local col = {
				u.customData.red,
				u.customData.green,
				u.customData.blue,
				255
			}
			map:newCar( id, x, y, col )
		end
	end
end

function game:sendNewCarPosition( x, y )
	-- CLIENT ONLY!
	if client then
		print("SENDING POSITION")
		client:send( CMD.MOVE_CAR, x .. "|" .. y )
	end
end

function game:startMovementRound()
	--SERVER ONLY!
	if server then
		server:send( CMD.GAMESTATE, "move" )
		self.GAMESTATE = "move"
		game.usersMoved = {}
	end
end

function game:moveAll()
	if server then
		for k, u in pairs( server:getUsers() ) do
			--local x, y = map:getCarPos( u.id )
			local x,y = self.newUserPositions[u.id].x, self.newUserPositions[u.id].y
			server:send( CMD.MOVE_CAR, u.id .. "|" .. x .. "|" .. y )
		end
	end
	self.timerEvent = function()
		game:startMovementRound()
	end
	self.maxTime = 1.2
end

function game:validateCarMovement( id, x, y )
	--SERVER ONLY!
	if server then
		-- if this user has not moved yet:
		if self.usersMoved[id] == nil then
--			map:setCarPos( id, x, y )
			print( "server moving car to:", x, y)
			--map:setCarPosDirectly(id, x, y) --car-id as number, pos as Gridpos
			local newX, newY = map:getCarPos( id )
			print( newX, newY )
			self.usersMoved[id] = true
			self.newUserPositions[id] = {x=x, y=y}

			-- tell this user to wait!
			local user = server:getUsers()[id]
			if user then
				server:send( CMD.GAMESTATE, "wait", user )
			end

			-- Check if all users have sent their move:
			local doneMoving = true
			for k, u in pairs( server:getUsers() ) do
				if not self.usersMoved[u.id] then
					doneMoving = false
					break
				end
			end
			-- If all users have sent the move, go on to next round:
			if doneMoving then
				self:moveAll()
			end
		end
	end
end

function game:moveCar( msg )
	-- CLIENT ONLY!
	if client then
		local id, x, y = msg:match( "(.*)|(.*)|(.*)" )
		id = tonumber(id)
		x = tonumber(x)
		y = tonumber(y)
		map:setCarPos( id, x, y )
	end
end
return game
