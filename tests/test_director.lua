require 'support'
set('JoinGrace', 0)
local d, g = fixture()
d:Step(10); equal(d.data.elapsed, 0); equal(#g.started, 0, 'disabled by default')
set('Enabled', true); d:Step(0)
equal(d.data.nextAt, 3600, 'rare initial interval')
d.data.nextAt = 0; g.ready = false; d:Step(1)
equal(g.started[1].kind, 'xp'); equal(g.started[1].value, 1.5)
equal(g.started[1].minutes, 10); equal(d.data.own.id, 'one')
d:Step(500); equal(#g.started, 1, 'one director event at a time')
g.active = {}; d:Step(0)
equal(d.data.nextAt, d.data.elapsed + 3600, 'interval starts at event completion')
local elapsed = d.data.elapsed
g.rows = {}; d:Step(100); equal(d.data.elapsed, elapsed, 'empty world freezes timer')
local restored, rg = fixture(d.data)
equal(restored.data.nextAt, d.data.nextAt, 'restart preserves deadline')
restored:Step(0); equal(restored.samples.Alice.joinedAt, elapsed, 'restart reconstructs join protection')
set('Enabled', false); restored:Step(100); equal(restored.data.elapsed, elapsed)
set('Enabled', true)

d, g = fixture(); d:Step(0); d.data.nextAt = 0
g.active.money = { id = 'admin' }; d:Step(1)
equal(#g.started, 0); equal(d.data.reason, 'ActiveEvent')
equal(g.active.money.id, 'admin', 'manual event untouched')
g.active = { horde = { id = 'native' } }; d:Step(1)
g.active = {}; d:Step(1)
check(d.data.recoveryUntil > d.data.elapsed, 'native horde ending grants rest')
d.data.nextAt = 0; d.decisionAt = 0; d:Step(1)
equal(d.data.reason, 'Recovery'); equal(#g.started, 0)

d, g = fixture(); d:Step(0)
g.rows[1].health = 90; d:Step(1)
equal(d.players[1].damageAt, d.data.elapsed - 1, 'damage tracked')
g.rows[1].kills = 20; d:Step(1)
equal(d.players[1].recentKills, 20)
d:Step(301); d:Step(0); equal(d.players[1].recentKills, 0, 'kills age out')
g.rows[1].dead = true; d:Step(1)
check(d.data.recoveryUntil > d.data.elapsed, 'death grants rest')

d, g = fixture(); d:Step(0); d.data.nextAt = 0; g.fail = true
d:Step(1)
equal(d.data.reason, 'StartFailed'); equal(d.data.nextAt, d.data.elapsed + 300)
equal(d.data.own, nil)
for i = 1, 30 do d:Record('Waiting') end
equal(#d.data.history, 20)

d, g = fixture(); d:Step(0); d.data.nextAt = 0
set('ThreatChance1', 100); d:Step(1)
equal(g.started[1].kind, 'horde'); equal(d.data.lastTargets.Alice, d.data.elapsed)
g.active.money = { id = 'ticket' }; d:Step(1)
equal(g.active.money.id, 'ticket', 'later external event can coexist')

d, g = fixture(); d:Step(0); d.data.nextAt = 0
local reads = 0
local read = g.ReadPlayer
g.ReadPlayer = function(p)
    reads = reads + 1
    local result = read(p)
    if reads >= 3 then result.health = 10 end
    return result
end
d:Step(1)
equal(#g.started, 0, 'revalidate target immediately before attack')
equal(d.data.reason, 'TargetChanged')

d, g = fixture(); d:Step(0); d.data.nextAt = 0
g.available = {}; g.ready = false; d:Step(1)
equal(d.data.reason, 'NoEligibleEvent')
d.data.nextAt = 0; d.decisionAt = 0; g.available = { 'xp' }; g.rows[1].health = 10; d:Step(1)
equal(g.started[1].kind, 'xp', 'unsafe target can still receive global opportunity')

d, g = fixture(); d:Step(0)
set('Preset', 3); d:Step(0)
equal(d.data.nextAt, d.data.elapsed + 900, 'preset change reschedules pending interval')

d, g = fixture(); set('Enabled', true); set('ThreatChance1', 0); d:Step(0)
local scheduled = d.data.nextAt
check(scheduled > d.data.elapsed, 'manual decision test starts before scheduled deadline')
local accepted, result = d:ForceDecision()
equal(accepted, true); equal(result, 'OpportunityStarted')
equal(#g.started, 1, 'manual decision bypasses only the schedule')
equal(g.started[1].kind, 'xp')

d, g = fixture(); set('Enabled', true); set('ThreatChance1', 100); set('xp_Enabled', false); set('money_Enabled', false)
set('box_Enabled', false); set('blood_Enabled', false); set('soul_Enabled', false); set('marrow_Enabled', false); set('bile_Enabled', false)
d:Step(0); g.rows[1].health = 10
accepted, result = d:ForceDecision()
equal(accepted, true); equal(result, 'NoEligibleEvent', 'manual decision still applies target protection')
equal(#g.started, 0, 'manual decision cannot bypass survivor protection')

d, g = fixture(); set('Enabled', true); d:Step(0); g.active.money = { id='admin' }
accepted, result = d:ForceDecision()
equal(result, 'ActiveEvent'); equal(g.active.money.id, 'admin', 'manual decision does not replace an external event')

d, g = fixture(); set('Enabled', false)
accepted, result = d:ForceDecision()
equal(accepted, false); equal(result, 'Disabled'); equal(#g.started, 0, 'manual decision respects the off switch')

d, g = fixture(); set('Enabled', true); d:Step(0); g.active.horde = { id = 'native' }
d:Step(0); g.active = {}
accepted, result = d:ForceDecision()
equal(result, 'Recovery', 'manual decision observes a just-ended native horde')
equal(#g.started, 0, 'manual decision does not bypass horde recovery')
