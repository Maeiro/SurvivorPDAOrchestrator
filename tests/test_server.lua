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
package.loaded['SPDO/Night'] = { Status = function() return {} end }
package.loaded['SPDO/NightSprinters'] = {}
stored.nightSettingsMigrated = true
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

isClient = function() return false end
wall = wall + 6000
local before, deadline, history = #g.started, stored.nextAt, #stored.history
request('SPDO', 'SimulateDecision', normal)
equal(#g.started, before, 'unauthorized simulation never starts an event')
local sentBefore = #sent
request('SPDO', 'SimulateDecision', normal)
equal(#sent, sentBefore, 'non-admin simulation denied')
request('SPDO', 'SimulateDecision', admin)
check(sent[#sent].args.simulation ~= nil, 'authorized simulation returns an explanation')
equal(#g.started, before, 'simulation cannot start an event')
equal(stored.nextAt, deadline, 'simulation preserves schedule')
equal(#stored.history, history, 'simulation preserves decision history')

isServer = function() return false end
isMultiplayer = function() return false end
getTimestampMs = function() return wall end
local paused = false
isGamePaused = function() return paused end
local updatePause = Events.OnTickEvenPaused.handlers[1]
Events.OnGameStart.handlers[1]()
tick()
local played = stored.elapsed
wall, hours = wall + 500, hours + 1
paused = true
updatePause()
wall, hours = wall + 2000, hours + 1
updatePause()
tick()
equal(stored.elapsed, played, 'SP director cannot step while paused')
paused = false
updatePause()
tick()
equal(stored.elapsed, played, 'resuming does not count a short pause as played time')
wall, hours = wall + 500, hours + 1
tick()
equal(stored.elapsed, played + 1, 'the director resumes from its remaining interval')

local native = {}
ModData.get = function(key) return native[key] end
PRPGE_XPBoostClient = {}
PRPGE_DropEventsClient = { drops = {} }
local events = {
    { kind = 'xp', key = 'PRPGE_XPBoost', hud = PRPGE_XPBoostClient, field = 'state' },
    { kind = 'box', key = 'PRPGE_BoxHunt', hud = PRPGE_XPBoostClient, field = 'hunt' },
    { kind = 'marrow', key = 'PRPGE_DropEvents', hud = PRPGE_DropEventsClient.drops, field = 'marrow' },
}
for _, item in ipairs(events) do
    local event = { id = 'director', startedAt = wall, endsAt = wall + 1000 }
    local hud = { id = event.id, endsAt = event.endsAt }
    item.hud[item.field] = hud
    native[item.key] = item.kind == 'marrow' and { marrow = event } or event
    stored.own = { kind = item.kind, id = event.id }
    paused = true
    updatePause()
    wall = wall + 3000
    updatePause()
    equal(event.endsAt - wall, 1000, item.kind .. ' bonus survives a pause longer than the remaining duration')
    equal(hud.endsAt - wall, 1000, item.kind .. ' HUD freezes with the bonus')
    paused = false
    wall = wall + 2000
    updatePause()
    equal(event.endsAt - wall, 1000, item.kind .. ' deadline is corrected before the first unpaused tick')
    equal(hud.endsAt - wall, 1000, item.kind .. ' HUD resumes with the same time left')
    wall = wall + 500
    updatePause()
    equal(event.endsAt - wall, 500, item.kind .. ' uses real seconds during play')
end

local replacement = { id = 'manual', startedAt = wall, endsAt = wall + 1000 }
native.PRPGE_DropEvents.marrow = replacement
paused = true
updatePause()
wall = wall + 500
updatePause()
equal(replacement.endsAt - wall, 500, 'a manually replaced event keeps its native deadline')
paused = false
updatePause()
stored.own = { kind = 'marrow', id = replacement.id }
isServer = function() return true end
isMultiplayer = function() return true end
paused = true
updatePause()
wall = wall + 100
updatePause()
equal(replacement.endsAt - wall, 400, 'multiplayer ignores the single-player pause hook')
