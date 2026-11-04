local support = require 'support'
local A = require 'SPDO/Adaptive'
local C = support.config
set('Enabled', true); set('JoinGrace', 0); set('DamageGrace', 0)
local d, g = fixture()
d:Step(0)
g.rows[1].health = 60; d:Step(1)
g.rows[1].health = 100; d:Step(1)
check(d.players[1].tension >= 70, 'healing does not erase recent severe damage')
local tension = d.players[1].tension
d:Step(600); d:Step(0)
check(d.players[1].tension < tension, 'tension decays with played time')
local loaded = fixture(d.data)
loaded:Step(0)
check(loaded.players[1].tension > 0, 'tension survives a restart')

local a, b, c, far = player('A', 0), player('B', 80), player('C', 160), player('Far', 900)
a.tension = 80; b.tension = 0; c.tension = 0; far.tension = 0
A.Groups({a,b,c,far}, 100, { A = 100 }, 200, 30, {A=0.5})
equal(c.group, a.group, 'groups include connected teammates')
equal(c.tension, 80, 'nearby teammates share tension')
equal(c.groupRestUntil, 1900, 'rotating the horde target does not bypass group rest')
equal(c.pressure, 0.5, 'group uses the most conservative learned pressure')
check(far.group ~= a.group and far.tension == 0, 'separated players retain independent pressure')

local data = {lastPressureAt=0, opportunities={}, pressures={}}
local world = {stage=1,hour=22,nightSprinters=0}
local calm = A.Context({player()},world,data,3600,C.Get)
world.nightSprinters=50
local night = A.Context({player()},world,data,3600,C.Get)
equal(night.chance,calm.chance/2,'50% sprinters halves director threat probability')
local busy = A.Context({player()},world,data,0,C.Get)
check(busy.chance < night.chance,'quiet time restores pressure gradually')
set('xp_Weight',0)
equal(A.Context({player()},world,data,3600,C.Get).weights.xp,0,'context never revives zero weights')
set('xp_Weight',25)
check(calm.weights.xp > 2500,'early RPG progression favors XP')

d,g=fixture(); d:Step(0)
g.nextRandom=9876
local deadline, history, elapsed = d.data.nextAt,#d.data.history,d.data.elapsed
d:Simulate(); d:Simulate()
equal(g.nextRandom,9876,'simulation does not consume native randomness')
equal(d.data.nextAt,deadline); equal(d.data.elapsed,elapsed); equal(#d.data.history,history)
equal(#g.started,0)

set('OpportunityLimit',1);set('ThreatChance1',0)
d.data.opportunities={d.data.elapsed}
local kind,_,reason=d:Evaluate(d.players,g.Random)
equal(kind,nil);equal(reason,'OpportunityBudget','bonus limit allows waiting')
set('OpportunityLimit',4);set('ThreatChance1',100)
d,g=fixture();d:Step(0);d:ForceDecision()
equal(g.started[1].kind,'horde')
g.rows[1].health=60;d:Step(1)
g.rows[1].health=100;d:Step(1)
g.active={};d:Step(1)
equal(d.data.lastOutcome,'OutcomeSevere')
equal(d.data.pressures.Alice,0.75,'severe horde reduces future pressure')

d,g=fixture();d:Step(0);d:ForceDecision()
g.active.money={id='external'};d:Step(1)
g.active={};d:Step(1)
equal(d.data.lastOutcome,'OutcomeUncertain','external events prevent attribution')
equal(d.data.pressures.Alice,nil,'uncertain outcome does not adjust pressure')

d,g=fixture();d:Step(0);d:ForceDecision()
g.rows={};d:Step(1);g.active={};d:Step(1)
equal(d.data.lastOutcome,'OutcomeUncertain','disconnect does not count as an easy victory')

d,g=fixture();d:Step(0);d:ForceDecision()
local restored,rg=fixture(d.data);rg.active={};restored:Step(0)
equal(restored.data.lastOutcome,'OutcomeUncertain','reloaded horde loses reliable outcome observations')

d,g=fixture();d:Step(0);d.data.pressures.Alice=0.75;d:ForceDecision()
g.active={};d:Step(1)
equal(d.data.pressures.Alice,0.8,'manageable outcome restores pressure gradually')

d,g=fixture();d:Step(0);d:ForceDecision()
g.rows[1].known=false;d:Step(1);g.active={};d:Step(1)
equal(d.data.lastOutcome,'OutcomeUncertain','missing physical observations prevent learning')

d,g=fixture();d:Step(0);d:ForceDecision()
g.world.nightSprinters=50;d:Step(1);g.active={};d:Step(1)
equal(d.data.lastOutcome,'OutcomeUncertain','overlapping Night Event prevents attributing injuries to the horde')

set('AdaptiveEnabled',false)
local legacy=A.Context({player()},world,data,0,C.Get)
equal(legacy.chance,100,'adaptive pacing can be disabled')

