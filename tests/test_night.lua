local support = require 'support'
local callbacks = {}
Events = setmetatable({}, { __index = function(t, key)
    local event = { Add = function(fn) callbacks[key] = fn end }
    rawset(t, key, event)
    return event
end })

local ready = false
local gameTime = {
    isNight = function() if not ready then error('season is not available') end; return true end,
    getYear = function() return 1 end,
    getDay = function() return 3 end,
    getMonth = function() return 0 end,
    daysInMonth = function() return 30 end,
    getHour = function() return 22 end,
    getDawn = function() return 6 end,
}
getGameTime = function() return gameTime end
ZombRand = function() return 0 end
ModData = { getOrCreate = function() return { nightCycle = 1, active = true, level = 2 } end }
isClient = function() return false end
isServer = function() return false end

local night = require 'SPDO/Night'
local ok = pcall(callbacks.OnInitGlobalModData)
equal(ok, true, 'night refresh tolerates climate season not ready during global mod data init')
equal(night.isNight, false, 'unavailable climate state does not activate night event')

ready = true
callbacks.EveryOneMinute()
equal(night.isNight, true, 'night state refreshes after climate season becomes available')
