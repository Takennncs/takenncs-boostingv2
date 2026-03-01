local QBCore = exports['qb-core']:GetCoreObject()
local availableContracts = {}
local currentContracts = {}
local loadedPlayers = {}
local pendingItems = {}

local function GetVehiclesByClass(vehicleClass)
    local vehicles = {}
    local allVehicles = QBCore.Shared.Vehicles or {}
    
    for model, data in pairs(allVehicles) do
        if data.class == vehicleClass then
            table.insert(vehicles, {
                model = model,
                name = data.name or model,
                class = data.class,
                price = data.price or 0
            })
        end
    end
    
    return vehicles
end

local function getRandomVehicleByClass(vehicleClass)
    local vehicles = GetVehiclesByClass(vehicleClass)
    if #vehicles > 0 then
        return vehicles[math.random(#vehicles)]
    end
    
    local allVehicles = {}
    for model, data in pairs(QBCore.Shared.Vehicles or {}) do
        table.insert(allVehicles, {
            model = model,
            name = data.name or model,
            class = data.class,
            price = data.price or 0
        })
    end
    
    if #allVehicles > 0 then
        return allVehicles[math.random(#allVehicles)]
    end
    
    return {
        model = 'adder',
        name = 'Adder',
        class = 'super',
        price = 1000000
    }
end

local function generateId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = ''
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end
    return id .. '-' .. os.time()
end

local function generatePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        plate = plate .. string.sub(chars, rand, rand)
    end
    return plate
end

local function loadPlayer(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end
    
    local citizenid = player.PlayerData.citizenid
    
    loadedPlayers[source] = {
        xp = 0,
        finished = 0,
        failed = 0,
        total_earned = 0,
        premium_contracts = 0,
        special_contracts = 0,
        queued = false
    }
    
    local result = MySQL.single.await('SELECT * FROM `takenncs_boosting` WHERE charId = ?', { citizenid })
    
    if result then
        loadedPlayers[source].xp = result.xp or 0
        loadedPlayers[source].finished = result.finished or 0
        loadedPlayers[source].failed = result.failed or 0
        loadedPlayers[source].total_earned = result.total_earned or 0
        loadedPlayers[source].premium_contracts = result.premium_contracts or 0
        loadedPlayers[source].special_contracts = result.special_contracts or 0
    else
        MySQL.insert('INSERT INTO `takenncs_boosting` (charId, xp, finished, failed, total_earned, premium_contracts, special_contracts) VALUES (?, 0, 0, 0, 0, 0, 0)',
            { citizenid })
    end
    
    local activeContract = MySQL.single.await('SELECT * FROM `takenncs_boosting_active` WHERE charId = ? AND expires_at > NOW()', 
        { citizenid })
    
    if activeContract then
        currentContracts[citizenid] = {
            id = activeContract.id,
            vehicleModel = activeContract.vehicle_model,
            vehicleName = activeContract.vehicle_name,
            plate = activeContract.plate,
            price = activeContract.price,
            difficulty = activeContract.difficulty,
            location = json.decode(activeContract.spawn_location),
            delivery = json.decode(activeContract.delivery_location),
            created = os.time()
        }
    end
end

local function savePlayer(source, citizenid)
    if not loadedPlayers[source] then return end
    
    MySQL.update('UPDATE `takenncs_boosting` SET xp = ?, finished = ?, failed = ?, total_earned = ?, premium_contracts = ?, special_contracts = ? WHERE charId = ?', {
        loadedPlayers[source].xp,
        loadedPlayers[source].finished,
        loadedPlayers[source].failed,
        loadedPlayers[source].total_earned,
        loadedPlayers[source].premium_contracts,
        loadedPlayers[source].special_contracts,
        citizenid
    })
end

AddEventHandler('ox:playerLoaded', function(source)
    loadPlayer(source)
end)

AddEventHandler('playerDropped', function()
    if loadedPlayers[source] then
        local player = QBCore.Functions.GetPlayer(source)
        if player then
            savePlayer(source, player.PlayerData.citizenid)
        end
        loadedPlayers[source] = nil
    end
end)

CreateThread(function()
    local players = QBCore.Functions.GetPlayers()
    for _, source in pairs(players) do
        local player = QBCore.Functions.GetPlayer(source)
        if player then
            loadPlayer(source)
        end
    end
end)

local function calculatePrice(vehicleClass, difficulty, levelMultiplier)
    local basePrice = cfg.priceRanges[vehicleClass] or { min = 1000, max = 3000 }
    local base = math.random(basePrice.min, basePrice.max)
    local difficultyMultiplier = cfg.difficultyMultipliers[difficulty] or 1.0
    
    return math.floor(base * difficultyMultiplier * levelMultiplier)
end

local function generateContract(level, isSpecial, isPremium)
    local vehicleClass
    
    if isSpecial then
        local specialClasses = {'super', 'sports', 'muscle', 'offroad'}
        vehicleClass = specialClasses[math.random(#specialClasses)]
    else
        vehicleClass = GetVehicleClassByLevel(level.id)
    end
    
    if not vehicleClass then
        vehicleClass = 'sedan'
    end
    
    local vehicle = getRandomVehicleByClass(vehicleClass)
    if not vehicle then
        vehicle = {
            model = 'adder',
            name = 'Adder',
            class = 'super'
        }
    end
    
    local difficulty = GetDifficultyByLevel(level.id, isSpecial)
    
    if not difficulty then
        difficulty = 'normal'
    end
    
    local price = calculatePrice(vehicleClass, difficulty, level.multiplier)
    
    if not price or price < 100 then
        price = 1000
    end
    
    local spawnLocation
    if isSpecial and cfg.specialSpawns and #cfg.specialSpawns > 0 then
        spawnLocation = cfg.specialSpawns[math.random(#cfg.specialSpawns)]
    else
        spawnLocation = cfg.vehicleSpawns[math.random(#cfg.vehicleSpawns)]
    end
    
    local deliveryLocation = cfg.deliveryPoints[math.random(#cfg.deliveryPoints)]
    
    return {
        id = generateId(),
        plate = generatePlate(),
        model = vehicle.model,
        vehicleName = vehicle.name,
        price = price,
        difficulty = difficulty,
        isSpecial = isSpecial or false,
        isPremium = isPremium or false,
        location = {
            x = spawnLocation.x,
            y = spawnLocation.y,
            z = spawnLocation.z,
            w = spawnLocation.w
        },
        delivery = {
            x = deliveryLocation.x,
            y = deliveryLocation.y,
            z = deliveryLocation.z,
            w = deliveryLocation.w
        },
        created = os.time()
    }
end

CreateThread(function()
    while true do
        local players = QBCore.Functions.GetPlayers()
        
        for _, source in pairs(players) do
            local player = QBCore.Functions.GetPlayer(source)
            if player and loadedPlayers[source] then
                local citizenid = player.PlayerData.citizenid
                local loadedPlayer = loadedPlayers[source]
                
                if availableContracts[citizenid] then
                    for i = #availableContracts[citizenid], 1, -1 do
                        if os.time() - availableContracts[citizenid][i].created > 3600 then
                            table.remove(availableContracts[citizenid], i)
                        end
                    end
                end
                
                if loadedPlayer and loadedPlayer.queued then
                    if not availableContracts[citizenid] then
                        availableContracts[citizenid] = {}
                    end
                    
                    if #availableContracts[citizenid] < 3 then
                        local level = GetLevelByXP(loadedPlayer.xp)
                        
                        local isSpecial = level.specialContracts and math.random() < 0.2
                        local isPremium = level.premiumContracts and math.random() < 0.1
                        
                        local contract = generateContract(level, isSpecial, isPremium)
                        
                        table.insert(availableContracts[citizenid], contract)
                        
                        TriggerClientEvent('takenncs-boostingv2:client:updateData', source)
                        TriggerClientEvent('QBCore:Notify', source, 'Uus tööots saadaval: ' .. contract.vehicleName .. ' ($' .. contract.price .. ')', 'success')
                    end
                end
            end
        end
        
        Wait(math.random(cfg.contractTime.min, cfg.contractTime.max) * 60000)
    end
end)

lib.callback.register('takenncs-boostingv2:requestData', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or not loadedPlayers[source] then
        return {
            inQueue = false,
            availableContracts = {},
            boostingXp = 0,
            stats = { finished = 0, failed = 0, total_earned = 0, special_contracts = 0, premium_contracts = 0 },
            currentContract = nil,
            levels = Levels,
            leaderboard = {},
            shopItems = cfg.shopItems or {},
            pendingItems = pendingItems[source] or {}
        }
    end
    
    local citizenid = player.PlayerData.citizenid
    local loadedPlayer = loadedPlayers[source]
    
    local leaderboard = MySQL.query.await([[
        SELECT charId, xp, finished 
        FROM `takenncs_boosting` 
        ORDER BY xp DESC 
        LIMIT 20
    ]]) or {}
    
    for _, p in ipairs(leaderboard) do
        p.charId = p.charId or "Tundmatu"
        p.xp = p.xp or 0
        p.finished = p.finished or 0
        p.name = "Kasutaja " .. string.sub(p.charId, 1, 6)
    end

    return {
        inQueue = loadedPlayer.queued or false,
        availableContracts = availableContracts[citizenid] or {},
        boostingXp = loadedPlayer.xp or 0,
        stats = {
            finished = loadedPlayer.finished or 0,
            failed = loadedPlayer.failed or 0,
            total_earned = loadedPlayer.total_earned or 0,
            special_contracts = loadedPlayer.special_contracts or 0,
            premium_contracts = loadedPlayer.premium_contracts or 0
        },
        currentContract = currentContracts[citizenid],
        levels = Levels,
        leaderboard = leaderboard,
        shopItems = cfg.shopItems or {},
        pendingItems = pendingItems[source] or {}
    }
end)

lib.callback.register('takenncs-boostingv2:acceptContract', function(source, id)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or not loadedPlayers[source] then
        return false
    end
    
    local citizenid = player.PlayerData.citizenid
    
    if currentContracts[citizenid] then
        TriggerClientEvent('QBCore:Notify', source, 'Sul on juba aktiivne töö', 'error')
        return false
    end
    
    local contract = nil
    local contractIndex = nil
    if availableContracts[citizenid] then
        for i, c in ipairs(availableContracts[citizenid]) do
            if c.id == id then
                contract = c
                contractIndex = i
                break
            end
        end
    end
    
    if not contract then
        TriggerClientEvent('QBCore:Notify', source, 'Tööotsu ei leitud', 'error')
        return false
    end
    
    if player.PlayerData.money.bank < contract.price then
        TriggerClientEvent('QBCore:Notify', source, 'Pole piisavalt raha! Vaja: $' .. contract.price, 'error')
        return false
    end
    
    player.Functions.RemoveMoney('bank', contract.price)
    
    table.remove(availableContracts[citizenid], contractIndex)
    
    currentContracts[citizenid] = contract
    
    TriggerClientEvent('takenncs-boostingv2:client:acceptContract', source, contract)
    TriggerClientEvent('QBCore:Notify', source, 'Töö vastu võetud! Sõiduki asukoht on kaardil.', 'success')
    
    return true
end)

lib.callback.register('takenncs-boostingv2:cancelContract', function(source, id)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return false
    end
    
    local citizenid = player.PlayerData.citizenid
    
    if currentContracts[citizenid] and currentContracts[citizenid].id == id then
        currentContracts[citizenid] = nil
        TriggerClientEvent('QBCore:Notify', source, 'Töö tühistatud', 'success')
        return true
    end
    
    if availableContracts[citizenid] then
        for i, contract in ipairs(availableContracts[citizenid]) do
            if contract.id == id then
                table.remove(availableContracts[citizenid], i)
                TriggerClientEvent('QBCore:Notify', source, 'Töö tühistatud', 'success')
                return true
            end
        end
    end
    
    TriggerClientEvent('QBCore:Notify', source, 'Tööotsu ei leitud', 'error')
    return false
end)

lib.callback.register('takenncs-boostingv2:joinQueue', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or not loadedPlayers[source] then
        return false
    end
    
    if loadedPlayers[source].queued then
        TriggerClientEvent('QBCore:Notify', source, 'Oled juba järjekorras', 'error')
        return false
    end
    
    loadedPlayers[source].queued = true
    TriggerClientEvent('QBCore:Notify', source, 'Liitusid järjekorraga!', 'success')
    
    return true
end)

lib.callback.register('takenncs-boostingv2:leaveQueue', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or not loadedPlayers[source] then
        return false
    end
    
    if not loadedPlayers[source].queued then
        TriggerClientEvent('QBCore:Notify', source, 'Pole järjekorras', 'error')
        return false
    end
    
    loadedPlayers[source].queued = false
    TriggerClientEvent('QBCore:Notify', source, 'Lahkusid järjekorrast!', 'success')
    
    return true
end)

lib.callback.register('takenncs-boostingv2:receivePayment', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or not loadedPlayers[source] then
        return false
    end
    
    local citizenid = player.PlayerData.citizenid
    local contract = currentContracts[citizenid]
    
    if not contract then
        TriggerClientEvent('QBCore:Notify', source, 'Aktiivset tööd ei leitud', 'error')
        return false
    end
    
    local loadedPlayer = loadedPlayers[source]
    
    local baseXP = cfg.xpPerContract.success or 25
    local totalReward = contract.price
    
    local level = GetLevelByXP(loadedPlayer.xp)
    totalReward = math.floor(totalReward * level.multiplier)
    
    player.Functions.AddMoney('cash', totalReward, 'boosting-payment')
    
    loadedPlayer.xp = loadedPlayer.xp + baseXP
    loadedPlayer.finished = loadedPlayer.finished + 1
    loadedPlayer.total_earned = loadedPlayer.total_earned + totalReward
    
    if contract.isSpecial then
        loadedPlayer.special_contracts = loadedPlayer.special_contracts + 1
    end
    
    savePlayer(source, citizenid)
    
    currentContracts[citizenid] = nil
    
    TriggerClientEvent('takenncs-boostingv2:client:contractCompleted', source, {
        reward = totalReward,
        xp = baseXP
    })
    
    return true
end)

QBCore.Commands.Add('giveboost', 'Anna mängijale boosti töö', {
    { name = 'id', help = 'Mängija ID' },
    { name = 'vehicle', help = 'Sõiduki mudel (valikuline)' },
    { name = 'difficulty', help = 'Raskusaste (easy/normal/hard/expert/legendary) (valikuline)' }
}, true, function(source, args)
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Palun sisesta kehtiv mängija ID!', 'error')
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Mängijat ei leitud!', 'error')
        return
    end
    
    local citizenid = targetPlayer.PlayerData.citizenid
    
    local function generateId()
        local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        local id = ''
        for i = 1, 8 do
            local rand = math.random(1, #chars)
            id = id .. string.sub(chars, rand, rand)
        end
        return id .. '-' .. os.time()
    end
    
    local function generatePlate()
        local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        local plate = ''
        for i = 1, 8 do
            local rand = math.random(1, #chars)
            plate = plate .. string.sub(chars, rand, rand)
        end
        return plate
    end
    
    local vehicleModel = args[2] or 'adder'
    local vehicleData = nil
    
    if QBCore.Shared.Vehicles then
        for model, data in pairs(QBCore.Shared.Vehicles) do
            if model:lower() == vehicleModel:lower() or (data.name and data.name:lower() == vehicleModel:lower()) then
                vehicleData = {
                    model = model,
                    name = data.name or model,
                    class = data.class or 'super',
                    price = data.price or 100000
                }
                break
            end
        end
    end
    
    if not vehicleData then
        vehicleData = {
            model = vehicleModel,
            name = vehicleModel,
            class = 'super',
            price = 50000
        }
    end
    
    local difficulty = args[3] or 'normal'
    local validDifficulties = {'easy', 'normal', 'hard', 'expert', 'legendary'}
    
    local isValidDifficulty = false
    for _, v in ipairs(validDifficulties) do
        if v == difficulty then
            isValidDifficulty = true
            break
        end
    end
    
    if not isValidDifficulty then
        difficulty = 'normal'
    end
    
    local difficultyMultipliers = {
        easy = 1.0,
        normal = 1.5,
        hard = 2.0,
        expert = 2.5,
        legendary = 3.0
    }
    
    local multiplier = difficultyMultipliers[difficulty] or 1.5
    local basePrice = vehicleData.price or 50000
    local price = math.floor(basePrice * multiplier * 0.3)
    
    local spawnLocation = cfg.vehicleSpawns[math.random(#cfg.vehicleSpawns)]
    local deliveryLocation = cfg.deliveryPoints[math.random(#cfg.deliveryPoints)]
    
    local contract = {
        id = generateId(),
        plate = generatePlate(),
        model = vehicleData.model,
        vehicleName = vehicleData.name,
        price = price,
        difficulty = difficulty,
        isSpecial = (difficulty == 'expert' or difficulty == 'legendary'),
        isPremium = (difficulty == 'legendary'),
        location = {
            x = spawnLocation.x,
            y = spawnLocation.y,
            z = spawnLocation.z,
            w = spawnLocation.w
        },
        delivery = {
            x = deliveryLocation.x,
            y = deliveryLocation.y,
            z = deliveryLocation.z,
            w = deliveryLocation.w
        },
        created = os.time()
    }
    
    if not availableContracts[citizenid] then
        availableContracts[citizenid] = {}
    end
    
    table.insert(availableContracts[citizenid], contract)
    
    TriggerClientEvent('QBCore:Notify', targetId, 'Said uue boosti töö: ' .. vehicleData.name .. ' (' .. difficulty .. ')', 'success')
    TriggerClientEvent('takenncs-boostingv2:client:updateData', targetId)
    
    TriggerClientEvent('QBCore:Notify', source, 'Boosti töö antud mängijale ' .. targetPlayer.PlayerData.name, 'success')
end)