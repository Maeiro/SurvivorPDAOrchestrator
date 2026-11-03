local Config = require 'SPDO/Config'

local Night = {
    enabled = false,
    occurs = false,
    active = false,
    isNight = false,
    nightCycle = 0,
    level = 1,
    levelReady = false,
    lootBonusPercent = 0,
    sprinterPercentage = 0,
}

local nightDataKey = 'SurvivorPDAOrchestratorNight'
local legacyNightDataKey = 'ViewpointExtractionSupportNight'

local function getNightCycle(gameTime)
    local year = gameTime:getYear()
    local day = year * 400 + gameTime:getDay()
    for month = 0, gameTime:getMonth() - 1 do
        day = day + gameTime:daysInMonth(year, month)
    end
    if gameTime:getHour() < gameTime:getDawn() then day = day - 1 end
    return day
end

local function clamp(value, minimum, maximum, fallback)
    return math.max(minimum, math.min(maximum, tonumber(value) or fallback))
end

local function getLevels()
    local levels = {}
    for level = 1, 4 do
        levels[level] = {
            weight = clamp(Config.Get('NightLevel' .. level .. 'Weight'), 0, 100, 0),
            lootBonusPercent = clamp(Config.Get('NightLevel' .. level .. 'LootBonus'), 0, 500, 0),
            sprinterPercentage = clamp(Config.Get('NightLevel' .. level .. 'SprinterPercentage'), 0, 100, 0),
        }
    end
    return levels
end

local function chooseLevel(levels)
    local totalWeight = 0
    for level = 1, 4 do totalWeight = totalWeight + levels[level].weight end
    if totalWeight == 0 then return 1 end
    local roll = ZombRand(totalWeight)
    local accumulatedWeight = 0
    for level = 1, 4 do
        accumulatedWeight = accumulatedWeight + levels[level].weight
        if roll < accumulatedWeight then return level end
    end
    return 4
end

local function transmit()
    if isServer and isServer() and ModData.transmit then ModData.transmit(nightDataKey) end
end

local function getNightLevel(cycle, levels)
    if isClient and isClient() then
        local data = ModData and ModData.get and ModData.get(nightDataKey)
        if data and tonumber(data.nightCycle) == cycle then
            return clamp(data.level, 1, 4, 1), data.active == true, true
        end
        return 1, false, false
    end
    if not ModData or not ModData.getOrCreate then return 1, false, false end

    local data = ModData.getOrCreate(nightDataKey)
    if tonumber(data.nightCycle) ~= cycle then
        local legacy = ModData.get and ModData.get(legacyNightDataKey)
        local migratedLevel = legacy and tonumber(legacy.nightCycle) == cycle and tonumber(legacy.level)
        data.nightCycle = cycle
        if migratedLevel then
            data.active = legacy.active ~= false
            data.level = clamp(migratedLevel, 1, 4, 1)
        else
            data.active = ZombRand(100) < clamp(Config.Get('NightEventsChance'), 0, 100, 50)
            data.level = data.active and chooseLevel(levels) or 1
        end
        transmit()
    end
    return clamp(data.level, 1, 4, 1), data.active == true, true
end

local function refresh()
    local gameTime = getGameTime and getGameTime()
    if not gameTime then return end

    Night.enabled = Config.Get('NightEventsEnabled') == true
    Night.isNight = gameTime:isNight()
    Night.nightCycle = getNightCycle(gameTime)
    Night.levels = getLevels()
    Night.level = 1
    Night.occurs = false
    Night.levelReady = false
    if Night.enabled and Night.isNight then
        Night.level, Night.occurs, Night.levelReady = getNightLevel(Night.nightCycle, Night.levels)
    end

    Night.active = Night.enabled and Night.isNight and Night.levelReady and Night.occurs
    local selectedLevel = Night.levels[Night.level]
    Night.lootBonusPercent = Night.active and selectedLevel.lootBonusPercent or 0
    Night.sprinterPercentage = Night.active and selectedLevel.sprinterPercentage or 0

    local bridge = SurvivorPDAOrchestratorBridge
    if bridge and bridge.setNightLootState then
        bridge.setNightLootState(Night.active, Night.lootBonusPercent)
    end
end

function Night.StartManual()
    refresh()
    if not Night.enabled then return false, 'NightDisabled' end
    if not Night.isNight then return false, 'NightNotNight' end
    if Night.active then return false, 'NightAlreadyActive' end
    if not ModData or not ModData.getOrCreate then return false, 'NightUnavailable' end

    local data = ModData.getOrCreate(nightDataKey)
    data.nightCycle = Night.nightCycle
    data.active = true
    data.level = chooseLevel(Night.levels)
    transmit()
    refresh()
    return true, 'NightStarted'
end

function Night.EndManual()
    refresh()
    if not Night.isNight or not ModData or not ModData.getOrCreate then return false, 'NightNotActive' end

    local data = ModData.getOrCreate(nightDataKey)
    if tonumber(data.nightCycle) ~= Night.nightCycle or data.active ~= true then return false, 'NightNotActive' end

    data.active = false
    transmit()
    refresh()
    return true, 'NightEnded'
end

function Night.Status()
    refresh()
    return {
        enabled = Night.enabled,
        isNight = Night.isNight,
        active = Night.active,
        level = Night.level,
    }
end

Night.refresh = refresh
SurvivorPDAOrchestratorNight = Night

if Events.OnGameStart then Events.OnGameStart.Add(refresh) end
if Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(refresh) end
if Events.EveryOneMinute then Events.EveryOneMinute.Add(refresh) end
if Events.OnReceiveGlobalModData then
    Events.OnReceiveGlobalModData.Add(function(key)
        if key == nightDataKey then refresh() end
    end)
end

return Night
