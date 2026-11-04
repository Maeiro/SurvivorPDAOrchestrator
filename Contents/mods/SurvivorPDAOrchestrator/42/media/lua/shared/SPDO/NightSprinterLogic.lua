local Night = require 'SPDO/Night'

local checkedNightKey = 'ViewpointExtractionSupportNightCycle'
local originalSpeedKey = 'ViewpointExtractionSupportOriginalSpeed'
local sprinterKey = 'ViewpointExtractionSupportNightSprinter'

local Sprinters = {}

local function restoreSpeed(zombie, data)
    if not data[sprinterKey] then return end
    local speed = tonumber(data[originalSpeedKey])
    if data.RPGWorldDangerStage67 and data.RPGWorldDangerSpeed67 then
        local ok, danger = pcall(require, 'RPG_Shared_WorldDanger')
        if ok and danger and danger.speedOn and danger.speedOn() then
            speed = tonumber(data.RPGWorldDangerSpeed67) or speed
        end
    end
    if speed then zombie:doZombieSpeed(speed) end
    data[sprinterKey] = nil
    data[originalSpeedKey] = nil
end

local function process(zombie)
    if not zombie then return end
    local data = zombie:getModData()
    if not Night.active then
        restoreSpeed(zombie, data)
        data[checkedNightKey] = nil
        return
    end

    if data[checkedNightKey] == Night.nightCycle then
        if data[sprinterKey] and zombie:getSpeedType() ~= 1 then zombie:doSprinter() end
        return
    end

    data[checkedNightKey] = Night.nightCycle
    if Night.sprinterPercentage == 0 or zombie:isCrawling()
        or ZombRand(100) >= Night.sprinterPercentage then return end

    data[originalSpeedKey] = zombie:getSpeedType()
    data[sprinterKey] = true
    zombie:doSprinter()
    Night.RecordSprinter()
end

function Sprinters.Process(zombie)
    local ok, err = pcall(process, zombie)
    if not ok and not Sprinters._warning then
        Sprinters._warning = true
        print('[Survivor PDA Orchestrator] Night sprinter update failed: ' .. tostring(err))
    end
end

function Sprinters.InstallWorldDangerPriority()
    local ok, danger = pcall(require, 'RPG_Shared_WorldDanger')
    if not ok or not danger or type(danger.applyZombie) ~= 'function' or danger._spdoNightPriority then
        return false
    end

    local applyZombie = danger.applyZombie
    danger.applyZombie = function(zombie, authority, context)
        local result = applyZombie(zombie, authority, context)
        if not (isMultiplayer and isMultiplayer() and not (isServer and isServer())) then
            Sprinters.Process(zombie)
        end
        return result
    end
    danger._spdoNightPriority = true
    return true
end

return Sprinters
