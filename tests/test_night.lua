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
    getWorldAgeHours = function() return 22 end,
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

local data = {}
local rolls, sounds = 0, 0
ModData = { getOrCreate = function() return data end }
ZombRand = function() rolls = rolls + 1; return 0 end
getSpecificPlayer = function() return { setHaloNote = function() end } end
package.loaded.PRPGE_PDA = { Sound = function() sounds = sounds + 1 end }
package.loaded['SPDO/Locale'] = { Text = function(name) return name end }
set('NightEventsEnabled', true)
set('NightEventsChance', 100)
require 'SPDO_NightClient'

local function advance(day, time)
    gameTime.isNight = function() return time >= 18.65 or time < 8 end
    gameTime.getWorldAgeHours = function() return day * 24 + (time - 7) % 24 end
    gameTime.getHour = function() return math.floor(time) end
    gameTime.getDawn = function() return 12 end
    callbacks.EveryOneMinute()
    callbacks.OnTick()
end

advance(4, 18 + 40 / 60)
local cycle = night.nightCycle
equal(rolls, 2, 'dusk rolls occurrence and level')
equal(sounds, 1, 'dusk plays the start sound')
advance(4, 19)
equal(night.nightCycle, cycle, '19:00 preserves the night ID')
equal(rolls, 2, '19:00 does not roll the event again')
equal(sounds, 1, '19:00 does not replay the start sound')
advance(4, 0)
advance(5, 7.5)
equal(night.nightCycle, cycle, 'midnight and the 07:00 world-age boundary preserve the night ID')
equal(sounds, 1, 'the same event keeps its original notification')
advance(5, 8)
equal(night.active, false, 'the event ends at dawn')
advance(5, 12)
advance(5, 18 + 40 / 60)
equal(rolls, 4, 'the following dusk rolls a new event')
equal(sounds, 2, 'the following night has its own notification')

data = { nightCycle = 5, nightOpen = true, active = true, level = 3 }
advance(6, 19)
equal(night.nightCycle, 5, 'an open night saved with the old formula keeps its ID')
equal(night.level, 3, 'resuming an old open night keeps its level')
equal(rolls, 4, 'resuming an open night does not roll again')
equal(night.EndManual(), true, 'an open night with the old ID can still be ended manually')
