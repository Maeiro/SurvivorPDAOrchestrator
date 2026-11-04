local Sprinters = require 'SPDO/NightSprinterLogic'

local cursor = 0

Sprinters.InstallWorldDangerPriority()

local function onZombie(zombie)
    Sprinters.Process(zombie)
end

local function onMinute()
    Sprinters.InstallWorldDangerPriority()
    local cell = getCell and getCell() or nil
    local zombies = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombies or not zombies.size then return end

    local size = zombies:size()
    if size <= 0 then cursor = 0; return end
    if cursor >= size then cursor = 0 end
    local budget = math.min(500, size)
    for _ = 1, budget do
        local zombie = zombies:get(cursor)
        cursor = (cursor + 1) % size
        if zombie then
            local ok, err = pcall(Sprinters.Process, zombie)
            if not ok and not Sprinters._serverWarning then
                Sprinters._serverWarning = true
                print('[Survivor PDA Orchestrator] Night sprinter update failed: ' .. tostring(err))
            end
        end
    end
end

if Events then
    if Events.OnZombieCreate then Events.OnZombieCreate.Add(onZombie) end
    if Events.EveryOneMinute then Events.EveryOneMinute.Add(onMinute) end
end
