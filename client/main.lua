SetTimeout(500, function()
	TriggerServerEvent('ox_doorlock:getDoors')
end)

local function createDoor(door)
	local double = door.doors

	if double then
		for i = 1, 2 do
			AddDoorToSystem(double[i].hash, double[i].model, double[i].coords.x, double[i].coords.y, double[i].coords.z, false, false, false)
			DoorSystemSetDoorState(double[i].hash, 4)
			DoorSystemSetDoorState(double[i].hash, double[i].state)
		end
	else
		AddDoorToSystem(door.hash, door.model, door.coords.x, door.coords.y, door.coords.z, false, false, false)
		DoorSystemSetDoorState(door.hash, 4)
		DoorSystemSetDoorState(door.hash, door.state)
	end
end

local nearbyDoors = {}
local Entity = Entity

RegisterNetEvent('ox_doorlock:setDoors', function(data)
	doors = data

	for _, door in pairs(data) do
		createDoor(door)
	end

	while true do
		table.wipe(nearbyDoors)
		local coords = GetEntityCoords(cache.ped)

		for _, door in pairs(doors) do
			door.distance = #(coords - door.coords)

			if door.distance < 40 then
				local double = door.doors

				if not door.entity then
					if double then
						for i = 1, 2 do
							double[i].entity = GetClosestObjectOfType(double[i].coords.x, double[i].coords.y, double[i].coords.z, 0.5, double[i].model, false, false, false)
							Entity(double[i].entity).state.doorId = door.id
						end
					else
						local entity = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 0.5, door.model, false, false, false)
						local min, max = GetModelDimensions(door.model)
						local vecs = {
							GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, min.z),
							GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, max.z),
							GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, max.z),
							GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, min.z),
							GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, min.z),
							GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, max.z),
							GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, max.z),
							GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, min.z)
						}

						local centroid = vec(0,0,0)

						for i = 1, 8 do
							centroid += vecs[i]
						end

						door.entity = entity
						door.coords = centroid / 8
						Entity(entity).state.doorId = door.id
					end
				end

				nearbyDoors[#nearbyDoors + 1] = door
			elseif door.entity then
				door.entity = nil
			end
		end

		Wait(500)
	end
end)

RegisterNetEvent('ox_doorlock:setState', function(id, state, source, data)
	if data then
		doors[id] = data
		createDoor(data)
	end

	if source == cache.serverId then
		if state == 0 then
			lib.notify({
				type = 'success',
				icon = 'unlock',
				description = 'Unlocked door'
			})
		else
			lib.notify({
				type = 'success',
				icon = 'lock',
				description = 'Locked door'
			})
		end
	end

	local door = data or doors[id]
	local double = door.doors
	door.state = state

	if double then
		while not door.auto and door.state == 1 and double[1].entity do
			local doorOneHeading = double[1].heading
			local doorOneCurrentHeading = math.floor(GetEntityHeading(double[1].entity) + 0.5)

			if doorOneHeading == doorOneCurrentHeading then
				DoorSystemSetDoorState(double[1].hash, door.state)
			end

			local doorTwoHeading = double[2].heading
			local doorTwoCurrentHeading = math.floor(GetEntityHeading(double[2].entity) + 0.5)

			if doorTwoHeading == doorTwoCurrentHeading then
				DoorSystemSetDoorState(double[2].hash, door.state)
			end

			if doorOneHeading == doorOneCurrentHeading and doorTwoHeading == doorTwoCurrentHeading then break end
			Wait(0)
		end

		DoorSystemSetDoorState(double[1].hash, door.state)
		DoorSystemSetDoorState(double[2].hash, door.state)
	else
		while not door.auto and door.state == 1 and door.entity do
			local heading = math.floor(GetEntityHeading(door.entity) + 0.5)
			if heading == door.heading then break end
			Wait(0)
		end

		DoorSystemSetDoorState(door.hash, door.state)
	end
end)

RegisterNetEvent('ox_doorlock:editDoorlock', function(id, data)
	local door = doors[id]

	if not data and door.entity then
		Entity(door.entity).state.doorId = nil
		local double = door.doors

		if double then
			DoorSystemSetDoorState(double[1].hash, 0)
			DoorSystemSetDoorState(double[2].hash, 0)
		else
			DoorSystemSetDoorState(door.hash, 0)
		end
	end

	doors[id] = data
end)

CreateThread(function()
	local lastTriggered = 0

	while true do
		local num = #nearbyDoors

		if num > 0 then
			for i = 1, num do
				local door = nearbyDoors[i]

				if door.distance < door.maxDistance then
					if IsDisabledControlJustReleased(0, 38) then
						local gameTimer = GetGameTimer()

						if gameTimer - lastTriggered > 500 then
							lastTriggered = gameTimer
							TriggerServerEvent('ox_doorlock:setState', door.id, door.state == 1 and 0 or 1)
						end
					end

					SetDrawOrigin(door.coords.x, door.coords.y, door.coords.z)
					SetTextScale(0.35, 0.35)
					SetTextFont(4)
					SetTextEntry('STRING')
					SetTextCentre(1)
					local text = door.state == 0 and 'Unlocked' or 'Locked'
					AddTextComponentString(text)
					DrawText(0.0, 0.0)
					DrawRect(0.0, 0.0125, 0.02 + text:len() / 360, 0.03, 25, 25, 25, 140)
					ClearDrawOrigin()
				end
			end
		end

		Wait(num > 0 and 0 or 500)
	end
end)