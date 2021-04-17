ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Make sure all Vehicles are Stored on restart
--MySQL.ready(function()
--    if Config.Main.ParkVehicles then
--        --ParkVehicles()
--        MySQL.Async.execute('UPDATE owned_vehicles SET `stored` = true WHERE `stored` = @stored', {
--            ['@stored'] = false
--        }, function(rowsChanged)
--            if rowsChanged > 0 then
--                print(('esx_advancedgarage: %s vehicle(s) have been stored!'):format(rowsChanged))
--            end
--        end)
--    else
--        print('esx_advancedgarage: Parking Vehicles on restart is currently set to false.')
--    end
--end)


ESX.RegisterServerCallback('bb_parking:CanVehicleBeStored', function(source, cb, props)
        local xPlayer = ESX.GetPlayerFromId(source)

        -- check that they're the owner
        MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND plate = @plate', {
            ['@owner'] = xPlayer.identifier,
            ['@plate'] = props.plate
        }, function (result)
            --for k,v in pairs(result[1]) do
            --    print(k,v)
            --end
            if #result <= 0 then cb(false) else cb(true) end
            cb(false) -- fall-through/default cond
        end)
end)


ESX.RegisterServerCallback('bb_parking:StoreVehicle', function(source, cb, vehicle, props, fuelLevel, parkingLot)
    local xPlayer = ESX.GetPlayerFromId(source)
    -- TODO either store damage state of vehicle or charge for repair when parking (i like the first opt, if possible)
    MySQL.Async.execute('UPDATE owned_vehicles SET  vehicle=@vehicle, stored=@stored, last_parked=@last_parked, fuel=@fuel WHERE owner=@owner AND plate=@plate', {
        ['@stored'] = 1,
        ['@last_parked'] = parkingLot,
        ['@vehicle'] = json.encode(props),
        ['@fuel'] = fuelLevel,
        ['@owner'] = xPlayer.identifier,
        ['@plate'] = props.plate
    }, function(rowsChanged)
        if rowsChanged == 0 then
            print(('esx_advancedgarage: %s exploited the garage!'):format(xPlayer.identifier))
            cb(false)
        else
            cb(true) -- return when updated
        end
    end)
end)

RegisterNetEvent('bb_parking:SetVehicleState')
AddEventHandler('bb_parking:SetVehicleState', function(plate, state)
    local xPlayer = ESX.GetPlayerFromId(source)
    print('plate', plate, 'state', state)
    MySQL.Async.fetchAll('UPDATE owned_vehicles SET stored=@stored WHERE owner=@owner AND plate=@plate', {
        ['@owner'] = xPlayer.identifier,
        ['@plate'] = plate,
        ['@stored'] = state,

    }, function(data)
        print('vehicle', plate, 'stored as', state)
    end)
end)




ESX.RegisterServerCallback('bb_parking:GetOwnedVehicles', function(source, cb, job)
    local xPlayer = ESX.GetPlayerFromId(source)

    local ownedVehicles = {}
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner=@owner AND type=@type AND stored=@stored', {
        ['@owner'] = xPlayer.identifier,
        ['@type'] = 'car',
        ['@stored'] = true,
    }, function(data)
        for _,v in pairs(data) do
            local vehicle = json.decode(v.vehicle)
            table.insert(ownedVehicles, {props = vehicle, plate = v.plate, name = v.name, fuel = v.fuel, stored = v.stored})
        end
        cb(ownedVehicles)
    end)
end)



