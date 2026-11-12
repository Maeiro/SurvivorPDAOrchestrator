if isClient and isClient() then return end

local Night = require 'SPDO/Night'
local Loot = {}
local wrappedRefresh
local requests = setmetatable({}, { __mode = 'k' })

local function bridge()
    local api = SurvivorPDAOrchestratorBridge
    return api and api.inspectNightLoot and api or nil
end

local function protected(container)
    local object = container:getParent()
    local square = object and object:getSquare()
    if not square then return true end
    if SafeHouse and SafeHouse.getSafeHouse and SafeHouse.getSafeHouse(square) then return true end
    local extraction = ExtractionMode
    if extraction then
        local hideouts = extraction.Hideouts
        if not hideouts or not hideouts.at then return true end
        if hideouts.at(square) then return true end
    end
    return false
end

function Loot.Inspect(player, container)
    local api = bridge()
    if not api or not player or not container or protected(container) or container:isLockedToCharacter(player) then return false end
    Night.refresh()
    local changed = api.inspectNightLoot(container, player, Night.active and Night.lootBonusPercent or 0)
    if changed and isServer and isServer() then sendItemsInContainer(container:getParent(), container) end
    return changed
end

local function integer(value)
    return type(value) == 'number' and value == math.floor(value) and math.abs(value) < 10000000
end

function Loot.Request(player, args)
    if not player or player:isDead() or type(args) ~= 'table' then return false end
    local now = getTimestampMs()
    local rate = requests[player]
    if not rate or now - rate.at >= 1000 or now < rate.at then
        rate = { at = now, count = 0 }; requests[player] = rate
    end
    rate.count = rate.count + 1
    if rate.count > 20 then return false end
    for _, key in ipairs({ 'x', 'y', 'z', 'object', 'container' }) do
        if not integer(args[key]) then return false end
    end
    if args.z ~= math.floor(player:getZ()) or math.abs(player:getX() - (args.x + 0.5)) > 3
        or math.abs(player:getY() - (args.y + 0.5)) > 3 then return false end
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    local objects = square and square:getObjects()
    if not objects or args.object < 0 or args.object >= objects:size() then return false end
    local object = objects:get(args.object)
    if args.container < 0 or args.container >= object:getContainerCount() then return false end
    local container = object:getContainerByIndex(args.container)
    if container:isLockedToCharacter(player) then return false end
    return Loot.Inspect(player, container)
end

function Loot.HookRefresh()
    local refresh = ExtractionMode and ExtractionMode.LocationRefresh
    if not refresh or type(refresh.refill) ~= 'function' or refresh.refill == wrappedRefresh then return end
    local original = refresh.refill
    wrappedRefresh = function(object, container, record, index)
        local api = bridge()
        if not api or not api.beginNightLootRefresh then return original(object, container, record, index) end
        local context = api.beginNightLootRefresh(container)
        local ok, result = pcall(original, object, container, record, index)
        api.finishNightLootRefresh(context, ok and result == true)
        if not ok then error(result) end
        return result
    end
    refresh.refill = wrappedRefresh
end

SPDO_InspectNightLoot = Loot.Inspect
Loot.HookRefresh()
if Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module == 'SPDO' and command == 'InspectLoot' then Loot.Request(player, args) end
    end)
end
if Events.OnGameStart then Events.OnGameStart.Add(Loot.HookRefresh) end
if Events.OnServerStarted then Events.OnServerStarted.Add(Loot.HookRefresh) end
if Events.EveryOneMinute then Events.EveryOneMinute.Add(Loot.HookRefresh) end
return Loot
