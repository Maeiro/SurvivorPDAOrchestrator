local Night = require 'SPDO/Night'

local checkedNightKey = 'ViewpointExtractionSupportNightCycle'
local originalSpeedKey = 'ViewpointExtractionSupportOriginalSpeed'
local sprinterKey = 'ViewpointExtractionSupportNightSprinter'

local function restoreSpeed(zombie, data)
    if data[sprinterKey] then
        zombie:doZombieSpeed(data[originalSpeedKey])
        data[sprinterKey] = nil
        data[originalSpeedKey] = nil
    end
end

local function updateZombie(zombie)
    if not zombie then return end
    local data = zombie:getModData()
    if not Night.enabled then
        restoreSpeed(zombie, data)
        data[checkedNightKey] = nil
        return
    end
    if not Night.isNight then
        restoreSpeed(zombie, data)
        data[checkedNightKey] = nil
        return
    end
    if not Night.levelReady or data[checkedNightKey] == Night.nightCycle then return end

    restoreSpeed(zombie, data)
    data[checkedNightKey] = Night.nightCycle
    if not Night.active then return end
    if Night.sprinterPercentage == 0 or zombie:isCrawling()
        or ZombRand(100) >= Night.sprinterPercentage then return end

    data[originalSpeedKey] = zombie:getSpeedType()
    data[sprinterKey] = true
    zombie:doSprinter()
end

if Events.OnZombieUpdate then Events.OnZombieUpdate.Add(updateZombie) end
