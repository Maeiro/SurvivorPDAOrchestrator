local support = require 'support'
local C, P = support.config, require 'SPDO/Policy'
set('JoinGrace', 0)
local p = player()
equal(P.Blocker(p, 0, C.Get), nil)
for field, value in pairs({ health = 79, endurance = .59, fatigue = .61, bleeding = true, sleeping = true, vehicle = true, known = false }) do
    local old = p[field]; p[field] = value
    check(P.Blocker(p, 1000, C.Get) ~= nil, 'unsafe field ' .. field)
    p[field] = old
end
p.damageAt = 1
equal(P.Blocker(p, 600, C.Get), 'RecentDamage')
equal(P.Blocker(p, 601, C.Get), nil)
p.damageAt = nil; p.recentKills = 20
equal(P.Blocker(p, 1000, C.Get), 'IntenseCombat')
p.recentKills = 0; p.extractionBlock = 'ExtractionUnknown'
equal(P.Blocker(p, 1000, C.Get), 'ExtractionUnknown')
set('ExtractionProtection', false)
equal(P.Blocker(p, 1000, C.Get), nil)
p.extractionBlock = nil
local weak = player('Bob', 30); weak.health = 20
local target = P.Target({ p, weak }, 1000, C.Get, {})
equal(target, nil, 'vulnerable neighbor blocks healthy target')
weak.x = 101
equal(P.Target({ p, weak }, 1000, C.Get, {}), p)
weak.x = 0; set('NeighborRadius', 0)
equal(P.Target({ p, weak }, 1000, C.Get, {}), p)
weak.health = 100
equal(P.Target({ p, weak }, 1000, C.Get, { Alice = 50 }), weak, 'fairness favors never attacked')
weak.level = 10
equal(P.Target({ p, weak }, 1000, C.Get, {}), weak, 'level breaks equal exposure ties')
equal(P.Opportunity({ 'xp', 'money' }, 'xp', C.Get, function() return 0 end), 'money')
equal(P.Opportunity({ 'xp' }, 'xp', C.Get, function() return 0 end), 'xp')
set('xp_Weight', 0)
equal(P.Opportunity({ 'xp' }, nil, C.Get, function() return 0 end), nil)
set('money_Enabled', false)
equal(P.Opportunity({ 'money' }, nil, C.Get, function() return 0 end), nil)
local low, high = C.Interval(); equal(low, 60); equal(high, 120)
set('Preset', 2); low, high = C.Interval(); equal(low, 30); equal(high, 60)
set('Preset', 3); low, high = C.Interval(); equal(low, 15); equal(high, 30)
set('Preset', 4); set('IntervalMin', 10); set('IntervalMax', 2)
low, high = C.Interval(); equal(low, 2); equal(high, 10)
