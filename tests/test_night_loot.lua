require 'support'
local callbacks, now, bonus, calls, broadcasts = {}, 1000, 200, 0, 0
Events = setmetatable({}, { __index = function(t, key)
    local event = { Add = function(f) callbacks[key] = f end }; rawset(t, key, event); return event
end })
isClient = function() return false end
isServer = function() return true end
getTimestampMs = function() return now end
package.loaded['SPDO/Night'] = { refresh = function() end, active = true, lootBonusPercent = bonus }
local player = { isDead = function() return false end, getX = function() return 10.5 end,
    getY = function() return 20.5 end, getZ = function() return 0 end }
local square = {}
local container = { getParent = function() return object end, isLockedToCharacter = function() return false end }
object = { getSquare = function() return square end, getContainerCount = function() return 1 end,
    getContainerByIndex = function() return container end }
square.getObjects = function() return { size = function() return 1 end, get = function() return object end } end
getCell = function() return { getGridSquare = function() return square end } end
sendItemsInContainer = function(obj, c) equal(obj, object); equal(c, container); broadcasts = broadcasts + 1 end
local saved = 'inspected'
SurvivorPDAOrchestratorBridge = {
    inspectNightLoot = function(c, p, amount)
        equal(c, container); equal(p, player); equal(amount, bonus); calls = calls + 1; return true
    end,
    beginNightLootRefresh = function() return saved end,
    finishNightLootRefresh = function(previous, success) if not success then saved = previous end end,
}
local loot = require 'SPDO/NightLoot'
local args = { x = 10, y = 20, z = 0, object = 0, container = 0 }
check(loot.Request(player, args), 'valid nearby inspection executes on authority')
equal(broadcasts, 1, 'added loot is synchronized')
args.x = 30
equal(loot.Request(player, args), false, 'distant container rejected')
args.x, args.object = 10, 9
equal(loot.Request(player, args), false, 'invalid object rejected')
args.object, args.container = 0, -1
equal(loot.Request(player, args), false, 'invalid container rejected')
args.container, args.x = 0, 0/0
equal(loot.Request(player, args), false, 'NaN coordinate rejected')
args.x = 10
container.isLockedToCharacter = function() return true end
equal(loot.Request(player, args), false, 'locked container rejected')
container.isLockedToCharacter = function() return false end
ExtractionMode = { Hideouts = { at = function() return {} end } }
equal(loot.Request(player, args), false, 'hideout is protected')
ExtractionMode.Hideouts = nil
equal(loot.Request(player, args), false, 'unknown hideout API fails safely')
ExtractionMode = nil
SafeHouse = { getSafeHouse = function() return {} end }
equal(loot.Request(player, args), false, 'safehouse is protected')
SafeHouse = nil
local before = calls
for i = 1, 30 do loot.Request(player, args) end
check(calls < before + 30, 'server rate limits repeated requests')
now = now + 1000
check(loot.Request(player, args), 'rate window recovers')

local fails = false
ExtractionMode = { LocationRefresh = { refill = function()
    saved = 'new cycle'
    if fails then error('native callback failure') end
    return true
end } }
loot.HookRefresh()
ExtractionMode.LocationRefresh.refill(object, container, {}, 0)
equal(saved, 'new cycle', 'successful Extraction refresh keeps new cycle')
saved, fails = 'previous inspected cycle', true
local ok = pcall(ExtractionMode.LocationRefresh.refill, object, container, {}, 0)
equal(ok, false, 'Extraction failure stays visible to its own transaction')
equal(saved, 'previous inspected cycle', 'failed refresh restores previous eligibility')
