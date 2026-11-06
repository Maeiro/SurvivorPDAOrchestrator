require 'support'

local handlers = {}
Events = setmetatable({}, { __index = function(t, key)
    handlers[key] = {}
    local event = { Add = function(fn) table.insert(handlers[key], fn) end }
    rawset(t, key, event)
    return event
end })
local function fire(event, ...)
    for _, fn in ipairs(handlers[event] or {}) do fn(...) end
end

local key = 'SurvivorPDAOrchestratorNight'
local tables, requests = {}, {}
ModData = {
    get = function(name) return tables[name] end,
    add = function(name, data) tables[name] = data end,
    request = function(name) requests[#requests + 1] = name end,
    getOrCreate = function() error('a multiplayer client must not create authority state') end,
}
isClient = function() return true end
isServer = function() return false end
isMultiplayer = function() return true end
local hour, age = 22, 22
getGameTime = function() return {
    isNight = function() return hour >= 20 or hour < 6 end,
    getWorldAgeHours = function() return age end,
    getHour = function() return hour end,
    getDawn = function() return 6 end,
} end
ZombRand = function() error('a multiplayer client must never roll the event') end
local boost = { Rows = function() return {} end }
package.loaded.PRPGE_XPBoostClient = boost
package.loaded['SPDO/Locale'] = { Text = function(name) return name end }
set('NightEventsEnabled', true)

local night = require 'SPDO/Night'
require 'SPDO_NightClient'
fire('OnGameStart')
equal(requests[1], key, 'joining requests the existing event from the dedicated server')
equal(night.active, false, 'no event is invented while waiting for the server')
equal(#boost.Rows(), 0, 'no HUD tag before synchronization')

fire('OnReceiveGlobalModData', 'AnotherMod', { active = true })
fire('OnReceiveGlobalModData', key, false)
equal(tables[key], nil, 'unrelated and unavailable payloads are ignored')

local state = { nightCycle = -1, nightOpen = true, active = true, level = 3 }
fire('OnReceiveGlobalModData', key, state)
equal(tables[key], state, 'received payload is stored for shared night consumers')
equal(night.levelReady, true, 'client accepts the authoritative level')
equal(night.active, true, 'late join sees the already running event')
equal(night.nightCycle, -1, 'client uses the open event ID from the server')
equal(night.lootBonusPercent, 150, 'HUD receives the configured level bonus')
equal(night.sprinterPercentage, 33, 'HUD receives the configured sprinter chance')
local rows = boost.Rows()
equal(#rows, 1, 'synchronized event appears in the native event list')
equal(rows[1][1], 'Item_SPDONightEvent', 'native event list uses the night icon')
equal(rows[1][2], '+150%', 'native event list shows the active loot bonus')

hour, age = 0, 24
fire('EveryOneMinute')
equal(night.level, 3, 'midnight preserves the received level')
equal(night.nightCycle, -1, 'client keeps the server event ID after refreshing the clock')
equal(#boost.Rows(), 1, 'midnight preserves the event tag')

fire('OnReceiveGlobalModData', key, { nightCycle = -1, nightOpen = true, active = false, level = 3 })
equal(night.active, false, 'remote manual end immediately clears client state')
equal(#boost.Rows(), 0, 'remote manual end removes the tag')

fire('OnReceiveGlobalModData', key, { nightCycle = 0, nightOpen = false, active = true, level = 3 })
equal(night.active, false, 'a closed server night stays closed when the client clock still reports night')

fire('OnReceiveGlobalModData', key, { nightCycle = -1, nightOpen = true, active = true, level = 2 })
equal(night.level, 2, 'remote manual start replaces the inactive state')
equal(#boost.Rows(), 1, 'remote manual start restores the tag')
hour, age = 7, 31
fire('EveryOneMinute')
equal(night.active, false, 'daytime stops the client event')
equal(#boost.Rows(), 0, 'dawn removes the tag')
