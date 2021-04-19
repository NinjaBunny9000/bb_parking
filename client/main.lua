ESX              = nil
local PlayerData = {}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerData = xPlayer   
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
  PlayerData.job = job
end)

local OwnedVehicles = {}

local State = {
	insideLot = false,
	insideVehicle = false
}


-------------------------------------------------------- MENUS ---------------------------------------------------------

local ParkingMenu = MenuV:CreateMenu(
		'PARKING',
		'Alta St Condos Lot // 8145',
		'centerleft',
		249, 244, 65,
		'size-125',
		'default',
		'menuv',
		'bb_parking'
)

ParkingMenu:On('open', function(m)
	--m:ClearItems()
end)

local CarMenu = MenuV:CreateMenu(
		'PARKING',
		'Vehicle Details',
		'centerleft',
		249, 244, 65
)

function closeMenus()
	MenuV:CloseMenu(ParkingMenu, function()
		MenuV:CloseMenu(CarMenu, function()

		end)
	end)

end

function reloadMenu(menu)
	MenuV:CloseMenu(ParkingMenu, function()
		print('parking menu closed')
		MenuV:CloseMenu(CarMenu, function()
			print('car menu closed')
			menu:Open()
		end)
	end)
end


-------------------------------------------------------- ZONES ---------------------------------------------------------

for zoneId,zone in pairs(Zones) do
	zone:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
		if isPointInside then -- player entered the zone
			State.insideLot = true
			State.lotId = zoneId
			CreateThread(function()
				-- track when ped gets in/out vehs while in the zone
				local playerPed = GetPlayerPed(PlayerId())
				while State.insideLot do
					Wait(250) -- makes sure we only do this (at most) once per frame, otherwise bad things happen D:
					if IsPedSittingInAnyVehicle(playerPed) then
						local msg = '💡 Press <span style="color:red;">E</span> to park'
						exports['mythic_notify']:PersistentHudText('START','bb_parking:PressEToPark', 'inform', msg, style)
					else
						local msg = '💡 Press <span style="color:red;">E</span> to find your car'
						exports['mythic_notify']:PersistentHudText('START','bb_parking:PressEToPark', 'inform', msg, style)
					end
				end
			end)
		else -- player left the zone
			State.insideLot = false
			State.lotId = nil
			OwnedVehicles = {}
			exports['mythic_notify']:PersistentHudText('END','bb_parking:PressEToPark')
		end
	end)
end


------------------------------------------------------- METHODS --------------------------------------------------------

function renameVehicle(plate)

	ESX.UI.Menu.CloseAll() -- make sure all other esx menus are closed
	ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'renamevehicle', {
		title = 'Give your ride a new name!'
	}, function(data, menu)
		if string.len(data.value) >= Config.VehicleProperties.nameMin and string.len(data.value) < Config.VehicleProperties.nameMax then
			ESX.TriggerServerCallback('bb_parking:UpdateVehicleName', function(success)
				ESX.UI.Menu.CloseAll()
				exports['bb_helpers']:notify(PlayerId(-1), 'pass', 'You changed your vehicle\'s name to '..data.value..'!', 5000)
				listVehicles()
			end, plate, data.value)
		else
			ESX.ShowNotification('You used too little or too many characters')
		end
	end, function(data, menu)
		closeMenus()
		menu.Close()
		ESX.UI.Menu.CloseAll()
	end)

end

function parkVehicle()
	local vehicle = GetVehiclePedIsIn(PlayerPedId())
	local vehProps = ESX.Game.GetVehicleProperties(vehicle)
	local parkingLotId = State.lotId

	ESX.TriggerServerCallback('bb_parking:CanVehicleBeStored', function(playerAllowedToStoreVehicle)
		local serverId = GetPlayerServerId(PlayerId())
		if playerAllowedToStoreVehicle then
			ESX.TriggerServerCallback('bb_parking:StoreVehicle', function()
				DeleteEntity(vehicle)
				exports['bb_helpers']:notify(serverId, 'pass', 'Your vehicle is parked at '..parkingLotId)
			end, vehicle, vehProps, exports['LegacyFuel']:GetFuel(vehicle), parkingLotId)
		else
			exports['bb_helpers']:notify(serverId, 'denied', 'You can\'t store a vehicle you don\'t own!')
		end
	end, vehProps)
end

function listVehicles()
	ESX.TriggerServerCallback('bb_parking:GetOwnedVehicles', function(ownedVehicles)
		OwnedVehicles = ownedVehicles
		ParkingMenu:ClearItems()
		local menuItems = {}
		local carItems = {}
		for i,veh in pairs(ownedVehicles) do
			menuItems[i] = ParkingMenu:AddButton({ icon='🚘', label=veh.name, description='San Andreas Plate #'..veh.plate, value= CarMenu, disabled=false });
			menuItems[i]:On('select', function(item)
				-- TODO update subtitle to show the correct lot
				CarMenu:ClearItems()
				-- add items for the car
				carItems[i] = {}
				carItems[i].rename = CarMenu:AddButton({ icon='🆎', label='Name Vehicle', description='Give it a custom name!', value=veh.plate, disabled=false })
				carItems[i].retrieve = CarMenu:AddButton({ icon='🔑', label='Retrieve Vehicle', description='Spwn '..veh.plate, value=veh.plate, disabled=false })
				carItems[i].rename:On('select', function(selection)
					renameVehicle(carItems[i].rename:GetValue(selection))
				end)
				carItems[i].retrieve:On('select', function(selection)
					closeMenus()
					retrieveVehicle(carItems[i].retrieve:GetValue(selection))
				end)
			end)
		end
		ParkingMenu:Close()
		ParkingMenu:Open()
	end)
end

function applyVehicleSettings(spawnedVeh, storedData)
	ESX.Game.SetVehicleProperties(spawnedVeh, storedData.props)
	exports['LegacyFuel']:SetFuel(spawnedVeh, storedData.fuel)
	SetVehRadioStation(spawnedVeh, "OFF")
	SetVehicleFixed(spawnedVeh)
	SetVehicleDeformationFixed(spawnedVeh)
	--SetVehicleEngineHealth(callback_vehicle, 1000) -- Might not be needed
	--SetVehicleBodyHealth(callback_vehicle, 1000) -- Might not be needed
end

-- TODO move to bb_helpers/bb_core
function getDistanceBetween(p1, p2)
	local x = (p2.x - p1.x) * (p2.x - p1.x)
	local y = (p2.y - p1.y) * (p2.y - p1.y)
	local z = (p2.z - p1.z) * (p2.z - p1.z)
	return math.sqrt(x + y + z)
end

function findClosestEmptyParkingSpot(zone)
	local playerCoord = GetEntityCoords(PlayerPedId())
	local closestSpot = {
		coord = vector3(0.0, 0.0, 0.0),
		dist = nil
	}

	local dist, closestVehDist
	for i,parkingSpot in pairs(ZoneProperties[zone].parkingSpots) do
		dist = getDistanceBetween(playerCoord, parkingSpot[1])
		closestVehDist = getDistanceBetween(parkingSpot[1], GetEntityCoords(ESX.Game.GetClosestVehicle(parkingSpot[1])))
		if closestSpot.dist == nil and closestVehDist < 1.5 then -- the first spot is closest but it's occupied
		elseif closestSpot.dist == nil or (dist < closestSpot.dist and closestVehDist > 1.5) then
			closestSpot.coord = parkingSpot[1]
			closestSpot.heading = parkingSpot[2]
			closestSpot.dist = dist
		end
	end

	return closestSpot
end

function disableVehicle(vehicle, state)
	if state == true then
		SetVehicleEngineOn(vehicle, false, true)
		SetVehicleUndriveable(vehicle, true)
	else
		SetVehicleEngineOn(vehicle, true, true)
		SetVehicleUndriveable(vehicle, false)
	end
end


function retrieveVehicle(plate)

	local storedData
	for i,veh in pairs(OwnedVehicles) do
		if veh.plate == plate then
			storedData = veh
		end
	end

	-- spawn the vehicle in the closest empty parking spot, put the player in it, and give them the keys
	local closestSpot = findClosestEmptyParkingSpot(State.lotId)
	ESX.Game.SpawnVehicle(storedData.props.model, closestSpot.coord, closestSpot.heading, function(spawnedVeh)
		if Config.DEBUG then print('spawning', plate, 'at coord', closestSpot.coord, 'with heading', closestSpot.heading) end
		disableVehicle(spawnedVeh, true)
		applyVehicleSettings(spawnedVeh, storedData)
		TaskWarpPedIntoVehicle(GetPlayerPed(-1), spawnedVeh, -1)
		TriggerServerEvent('bb_parking:SetVehicleState', storedData.plate, false)
		TriggerEvent('bb_lockandkey:GiveKeys', storedData.plate, true)
		disableVehicle(spawnedVeh, false)
		ParkingMenu:Close()
	end)
	OwnedVehicles = {}
end


RegisterCommand('parkingmenu', function(source)
	-- make sure this command only works if they're inside a lot
	if State.insideLot == false then return end

	if IsPedSittingInAnyVehicle(GetPlayerPed(PlayerId())) then
		parkVehicle()
	else
		listVehicles()
	end

end, false)

RegisterKeyMapping('parkingmenu', '[VEHICLE] Parkinglot Menu', 'keyboard', 'e')
