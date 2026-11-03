local support = require 'support'
set('Enabled', true); set('JoinGrace', 0)
support.settings.values.AdminPanelEnabled = true
local _, g = fixture()
local wall, hours = 0, 0
g.Milliseconds = function() return wall end
g.Hours = function() return hours end
g.Authority = function() return not isClient() end
g.rows[1].isDead = function() return false end
package.loaded['SPDO/Game'] = g
local stored, sent, tick = {}, {}, nil
ModData = { getOrCreate = function() return stored end }
isClient = function() return false end
isServer = function() return true end
isMultiplayer = function() return true end
sendServerCommand = function(p, module, command, args) sent[#sent + 1] = { p = p, args = args } end
triggerEvent = function(_, module, command, args) sent[#sent + 1] = { args = args } end
Events = setmetatable({}, { __index = function(t, k)
    local e = { handlers = {} }; e.Add = function(fn) e.handlers[#e.handlers + 1] = fn end
    rawset(t, k, e); return e
end })
package.loaded.PRPGE_Tick = { Add = function(fn) tick = fn end }
package.loaded.PRPGE_SettingsServer = { CanEdit = function(p) return p.admin == true end }
require 'SPDO_Server'
Events.OnInitGlobalModData.handlers[1]()
tick()
wall, hours = 1000, 1; tick(); equal(stored.elapsed, 1)
wall, hours = 2000, 100; tick(); equal(stored.elapsed, 2, 'time acceleration does not accelerate director')
wall = 3000; tick(); equal(stored.elapsed, 2, 'paused simulation')
wall, hours = 1000000, 101; tick(); equal(stored.elapsed, 2, 'pause or stall does not accrue catchup')
wall, hours = 1001000, 102; tick(); equal(stored.elapsed, 3)
local rows = g.rows; g.rows = {}; wall, hours = 1002000, 103; tick(); equal(stored.elapsed, 3, 'empty server')
g.rows = rows
Events.OnGameStart.handlers[1](); wall, hours = 2000000, 104; tick(); equal(stored.elapsed, 3, 'restart resets wall clock baseline')
local request = Events.OnClientCommand.handlers[1]
local normal, admin = {}, { admin = true }
request('SPDO', 'Get', normal); equal(#sent, 0, 'non-admin diagnostic denied')
request('SPDO', 'StartHorde', admin); equal(#sent, 0, 'no remote event-start command')
request('SPDO', 'ForceDecision', normal); equal(#sent, 0, 'manual decision denied to non-admin')
request('SPDO', 'Get', admin); equal(#sent, 1)
request('SPDO', 'Get', admin); equal(#sent, 1, 'diagnostic requests throttled')
equal(SPDO_Request(admin, 'Get'), false, 'SP bridge unavailable in multiplayer')
isServer = function() return false end
isMultiplayer = function() return false end
wall = wall + 2001
equal(SPDO_Request(admin, 'Get'), true, 'SP diagnostic dispatch')
equal(#sent, 2)
support.settings.values.AdminPanelEnabled = false; wall = wall + 2001
equal(SPDO_Request(admin, 'Get'), false, 'SP admin feature permission respected')
support.settings.values.AdminPanelEnabled = true
isServer = function() return true end
isMultiplayer = function() return true end
set('Enabled', true); set('ThreatChance1', 0)
wall = wall + 2001; request('SPDO', 'ForceDecision', admin)
equal(#sent, 3, 'authorized admin can request a decision')
equal(sent[3].args.forceResult, 'OpportunityStarted', 'manual decision uses the director')
request('SPDO', 'ForceDecision', { admin = true })
equal(#sent, 4, 'second admin receives the global force cooldown response')
equal(sent[4].args.requestResult, 'ForceCooldown')
local count = stored.elapsed
isClient = function() return true end
wall, hours = wall + 1000, 105; tick(); equal(stored.elapsed, count, 'clients cannot run director')
