Levels = {
    {
        id = 1,
        label = 'Algaja',
        xp = 0,
        xpRequired = 100,
        multiplier = 1.0,
        color = '#6b7280',
        maxDifficulty = 'easy',
        specialSpawns = false,
        icon = '🌱',
        vehicleChances = {
            compact = 20,
            sedan = 25,
            suv = 20,
            coupe = 15,
            muscle = 10,
            motorcycle = 10
        }
    },
    {
        id = 2,
        label = 'Tööline',
        xp = 100,
        xpRequired = 300,
        multiplier = 1.2,
        color = '#10b981',
        maxDifficulty = 'normal',
        specialSpawns = false,
        icon = '🔧',
        vehicleChances = {
            compact = 10,
            sedan = 20,
            suv = 20,
            coupe = 15,
            muscle = 15,
            sports = 10,
            motorcycle = 10
        }
    },
    {
        id = 3,
        label = 'Kogenud',
        xp = 300,
        xpRequired = 600,
        multiplier = 1.5,
        color = '#3b82f6',
        maxDifficulty = 'hard',
        specialSpawns = false,
        icon = '⚡',
        vehicleChances = {
            sedan = 15,
            suv = 15,
            coupe = 15,
            muscle = 15,
            sports = 20,
            super = 10,
            offroad = 10
        }
    },
    {
        id = 4,
        label = 'Professionaal',
        xp = 600,
        xpRequired = 1000,
        multiplier = 1.8,
        color = '#8b5cf6',
        maxDifficulty = 'expert',
        specialSpawns = true,
        icon = '💎',
        vehicleChances = {
            coupe = 10,
            muscle = 10,
            sports = 25,
            super = 25,
            offroad = 15,
            motorcycle = 5
        }
    },
    {
        id = 5,
        label = 'Bossman',
        xp = 1000,
        xpRequired = 1500,
        multiplier = 2.2,
        color = '#f59e0b',
        maxDifficulty = 'legendary',
        specialSpawns = true,
        icon = '👑',
        vehicleChances = {
            sports = 15,
            super = 30,
            offroad = 10,
            emergency = 10,
            military = 15,
            helicopter = 10,
            plane = 5
        }
    }
}

function GetVehicleClassByLevel(levelId)
    local level = Levels[levelId] or Levels[1]
    local chances = level.vehicleChances or {
        sedan = 30,
        suv = 20,
        coupe = 15,
        muscle = 15,
        sports = 10,
        compact = 10
    }
    
    local total = 0
    for _, chance in pairs(chances) do
        total = total + chance
    end
    
    if total == 0 then
        return 'sedan'
    end
    
    local random = math.random(1, total)
    local current = 0
    
    for class, chance in pairs(chances) do
        current = current + chance
        if random <= current then
            return class
        end
    end
    
    return 'sedan'
end

function GetDifficultyByLevel(levelId, isSpecial)
    local level = Levels[levelId] or Levels[1]
    local difficulties = {'easy', 'normal', 'hard', 'expert', 'legendary'}
    local difficultyMap = {
        easy = 1,
        normal = 2,
        hard = 3,
        expert = 4,
        legendary = 5
    }
    
    local maxDifficultyIndex = difficultyMap[level.maxDifficulty] or 1
    
    if isSpecial and maxDifficultyIndex < #difficulties then
        maxDifficultyIndex = maxDifficultyIndex + 1
    end
    
    if math.random() < 0.7 then
        return difficulties[math.random(1, maxDifficultyIndex)]
    else
        if maxDifficultyIndex <= 1 then
            return difficulties[1]
        end
        return difficulties[math.random(1, maxDifficultyIndex - 1)]
    end
end

function GetLevelByXP(xp)
    local currentLevel = Levels[1]
    for _, level in ipairs(Levels) do
        if xp >= level.xp then
            currentLevel = level
        else
            break
        end
    end
    return currentLevel
end

function GetNextLevel(currentLevel)
    for i, level in ipairs(Levels) do
        if level.id == currentLevel.id then
            return Levels[i + 1]
        end
    end
    return nil
end

function GetXPProgress(xp, currentLevel, nextLevel)
    if not nextLevel then
        return 100
    end
    local xpInCurrentLevel = xp - currentLevel.xp
    local xpNeeded = nextLevel.xp - currentLevel.xp
    return (xpInCurrentLevel / xpNeeded) * 100
end