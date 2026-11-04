if isMultiplayer and isMultiplayer() then return end

local Sprinters = require 'SPDO/NightSprinterLogic'

local CYCLE = 2000
local cursor, last, carry = 0, nil, 0

Sprinters.InstallWorldDangerPriority()

local function onZombie(zombie)
    Sprinters.Process(zombie)
end

local function onTick()
    Sprinters.InstallWorldDangerPriority()
    local now = getTimestampMs and tonumber(getTimestampMs()) or nil
    if not now then return end
    if not last or now < last then last = now; return end
    local elapsed = math.min(CYCLE, now - last)
    last = now
    if elapsed <= 0 then return end

    local cell = getCell and getCell() or nil
    local zombies = cell and cell.getZombieList and cell:getZombieList() or nil
    if not zombies then return end

    local size = zombies:size()
    if size <= 0 then cursor, carry = 0, 0; return end
    carry = carry + size * elapsed / CYCLE
    local count = math.floor(carry)
    if count < 1 then return end
    carry = carry - count
    if count > size then count, carry = size, 0 end

    for _ = 1, count do
        if cursor >= size then cursor = 0 end
        local zombie = zombies:get(cursor)
        cursor = cursor + 1
        if zombie then Sprinters.Process(zombie) end
    end
end

if Events then
    if Events.OnZombieCreate then Events.OnZombieCreate.Add(onZombie) end
    if Events.OnTick then Events.OnTick.Add(onTick) end
end
