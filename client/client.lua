local QBCore = exports['qb-core']:GetCoreObject()

local blips = {}
local spawnRadiusBlip = nil
local currentSpawned = false
local currentEntity = nil
local currentModel = nil
local currentPlate = nil
local currentLocation = nil
local currentDelivery = nil
local locationPoint = nil
local deliveryNPC = nil
local contractActive = false
local vehicleHealth = 1000

local function resetSettings()
    if spawnRadiusBlip and DoesBlipExist(spawnRadiusBlip) then
        RemoveBlip(spawnRadiusBlip)
        spawnRadiusBlip = nil
    end

    for i = 1, #blips do
        if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end
    end
    blips = {}

    if currentEntity and DoesEntityExist(currentEntity) then
        DeleteEntity(currentEntity)
        currentEntity = nil
    end

    if deliveryNPC and DoesEntityExist(deliveryNPC) then
        exports.ox_target:removeEntity(deliveryNPC, 'receive_payment')
        DeleteEntity(deliveryNPC)
        deliveryNPC = nil
    end

    if locationPoint then
        locationPoint:remove()
        locationPoint = nil
    end

    contractActive = false
    currentSpawned = false
    currentModel = nil
    currentPlate = nil
    currentLocation = nil
    currentDelivery = nil
    vehicleHealth = 1000
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then resetSettings() end
end)

local function createDeliveryPoint()
    if not currentDelivery or not currentDelivery.x then 
        return 
    end

    for i = #blips, 1, -1 do
        if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end
    end
    blips = {}

    local blip = AddBlipForCoord(currentDelivery.x, currentDelivery.y, currentDelivery.z)
    SetBlipSprite(blip, 227)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 1.0)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Kohalik")
    EndTextCommandSetBlipName(blip)
    table.insert(blips, blip)

    CreateThread(function()
        while contractActive and currentDelivery do
            Wait(0)
        end
    end)

    local npcModel = 's_m_m_dockwork_01'
    lib.requestModel(joaat(npcModel))
    deliveryNPC = CreatePed(4, joaat(npcModel), currentDelivery.x, currentDelivery.y, currentDelivery.z - 1.0, currentDelivery.w or 0.0, false, true)

    SetEntityInvincible(deliveryNPC, true)
    FreezeEntityPosition(deliveryNPC, true)
    SetBlockingOfNonTemporaryEvents(deliveryNPC, true)

    exports.ox_target:addLocalEntity(deliveryNPC, {
        {
            name = 'receive_payment',
            label = 'Anna sõiduk üle',
            icon = 'fas fa-money-bill-wave',
            distance = 3.0,
            onSelect = function()
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local veh = GetClosestVehicle(coords.x, coords.y, coords.z, 12.0, 0, 71)

                if not veh then
                    QBCore.Functions.Notify("Lähedal pole sõidukit", "error")
                    return
                end

                local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(veh))
                if plate ~= currentPlate then
                    QBCore.Functions.Notify("Vale sõiduk!", "error")
                    return
                end

                if IsPedInAnyVehicle(ped, false) then
                    QBCore.Functions.Notify("Välju sõidukist", "error")
                    return
                end

                lib.callback('takenncs-boostingv2:receivePayment', false, function(success)
                    if success then
                        DeleteEntity(veh)
                        resetSettings()
                        QBCore.Functions.Notify("Said boostiga edukalt hakkama.", "success")
                    else
                        QBCore.Functions.Notify("Üleandmine ebaõnnestus", "error")
                    end
                end)
            end
        }
    })
end

local function spawnVehicle()
    if not currentModel or not currentLocation then
        return
    end

    if spawnRadiusBlip and DoesBlipExist(spawnRadiusBlip) then
        RemoveBlip(spawnRadiusBlip)
        spawnRadiusBlip = nil
    end

    for i = #blips, 1, -1 do
        if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end
    end
    blips = {}

    local modelHash = joaat(currentModel)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            timeout = timeout + 1
            Wait(10)
        end
    end

    currentEntity = CreateVehicle(modelHash, currentLocation.x, currentLocation.y, currentLocation.z, currentLocation.w or 0.0, true, true)

    local attempts = 0
    while not DoesEntityExist(currentEntity) and attempts < 80 do
        Wait(25)
        attempts = attempts + 1
    end

    if not DoesEntityExist(currentEntity) then
        QBCore.Functions.Notify("Sõiduki loomine ebaõnnestus", "error")
        return
    end

    SetEntityHeading(currentEntity, currentLocation.w or 0.0)
    SetVehicleOnGroundProperly(currentEntity)
    SetVehicleNumberPlateText(currentEntity, currentPlate)
    SetVehicleDoorsLocked(currentEntity, 2)
    SetVehicleNeedsToBeHotwired(currentEntity, false)

    vehicleHealth = GetVehicleBodyHealth(currentEntity)

    CreateThread(function()
        while DoesEntityExist(currentEntity) and contractActive do
            Wait(600)
            if IsVehicleEngineOn(currentEntity) then
                if DoesBlipExist(vehBlip) then RemoveBlip(vehBlip) end
                if locationPoint then locationPoint:remove() locationPoint = nil end
                createDeliveryPoint()
                break
            end
        end
    end)

    CreateThread(function()
        while DoesEntityExist(currentEntity) and contractActive do
            Wait(5000)
            local h = GetVehicleBodyHealth(currentEntity)
            if h < vehicleHealth - 180 then
                vehicleHealth = h
                QBCore.Functions.Notify("Auto sai kahjustada – tasu väheneb!", "error")
            end
        end
    end)
end

local function createLocationPoint()
    if not currentLocation or not currentLocation.x or not currentLocation.y or not currentLocation.z then
        QBCore.Functions.Notify("Viga: sõiduki asukoht puudub / vigane", "error")
        return
    end

    if spawnRadiusBlip and DoesBlipExist(spawnRadiusBlip) then
        RemoveBlip(spawnRadiusBlip)
        spawnRadiusBlip = nil
    end

    for i = #blips, 1, -1 do
        if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end
    end
    blips = {}

    spawnRadiusBlip = AddBlipForRadius(currentLocation.x, currentLocation.y, currentLocation.z, 80.0)
    SetBlipColour(spawnRadiusBlip, 1)
    SetBlipAlpha(spawnRadiusBlip, 110)
    SetBlipAsShortRange(spawnRadiusBlip, false)

    CreateThread(function()
        while contractActive and currentLocation and not currentSpawned do
            DrawMarker(1,
                currentLocation.x, currentLocation.y, currentLocation.z - 1.0,
                0, 0, 0, 0, 0, 0,
                60.0, 60.0, 2.0,
                255, 60, 60, 100,
                false, true, 2, false, nil, nil, false)
            Wait(0)
        end
    end)

    if locationPoint then
        locationPoint:remove()
        locationPoint = nil
    end

    locationPoint = lib.points.new({
        coords = vector3(currentLocation.x, currentLocation.y, currentLocation.z),
        distance = 90.0,
        onEnter = function()
            if not currentSpawned then
                currentSpawned = true
                spawnVehicle()
            end
        end,
        onExit = function()
        end,
        nearby = function()
            if currentSpawned and currentEntity and DoesEntityExist(currentEntity) then
                DrawMarker(2, currentLocation.x, currentLocation.y, currentLocation.z + 2.0, 0,0,0,0,0,0, 1.5,1.5,1.5, 255,255,0,100, false,true,2,nil,nil,false)
            end
        end
    })
end

exports('openTablet', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMenu', data = { levels = Levels } })
end)

RegisterNUICallback('closeMenu', function(_, cb) SetNuiFocus(false, false) cb('ok') end)

RegisterNUICallback('requestData', function(_, cb)
    lib.callback('takenncs-boostingv2:requestData', false, cb)
end)

RegisterNUICallback('acceptContract', function(data, cb)
    lib.callback('takenncs-boostingv2:acceptContract', false, function(success)
        cb({ success = success })
    end, data.id)
end)

RegisterNUICallback('cancelContract', function(data, cb)
    lib.callback('takenncs-boostingv2:cancelContract', false, function(success)
        if success then
            resetSettings()
        end
        cb({ success = success })
    end, data.id)
end)

RegisterNUICallback('joinQueue', function(_, cb)
    lib.callback('takenncs-boostingv2:joinQueue', false, function(success)
        cb({ success = success })
    end)
end)

RegisterNUICallback('leaveQueue', function(_, cb)
    lib.callback('takenncs-boostingv2:leaveQueue', false, function(success)
        cb({ success = success })
    end)
end)

RegisterNetEvent('takenncs-boostingv2:client:acceptContract', function(contract)
    if not contract then return end

    currentModel    = contract.model
    currentPlate    = contract.plate
    currentLocation = contract.location
    currentDelivery = contract.delivery
    contractActive  = true

    QBCore.Functions.Notify("Töö vastu võetud! Vaata kaarti – punane ring", "success")

    createLocationPoint()
end)

RegisterNetEvent('takenncs-boostingv2:client:contractCompleted', function(data)
    QBCore.Functions.Notify(('Lõpetatud! +$%s   +%s XP'):format(data.reward or 0, data.xp or 0), 'success')
    resetSettings()
end)

RegisterNetEvent('takenncs-boostingv2:client:contractCancelled', function()
    QBCore.Functions.Notify('Töö tühistatud', 'error')
    resetSettings()
end)

RegisterNetEvent('takenncs-boostingv2:client:updateData', function()
    SendNUIMessage({ action = 'updateData' })
end)