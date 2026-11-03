local support = require 'support'
local S = support.settings
CharacterStat = { ENDURANCE = 'endurance', FATIGUE = 'fatigue' }
isClient = function() return false end
isServer = function() return false end
getGameTime = function() return { getWorldAgeHours = function() return 10 end, getTimeOfDay = function() return 12 end } end
getActivatedMods = function() return { contains = function() return false end } end
local body = { getHealth = function() return 100 end, getNumPartsBleeding = function() return 0 end }
local stats = { get = function(_, stat) return stat == 'endurance' and 1 or 0 end }
local p = { getUsername = function() return 'Alice' end, isDead = function() return false end,
    getBodyDamage = function() return body end, getStats = function() return stats end,
    isAsleep = function() return false end, getVehicle = function() return nil end,
    getX = function() return 0 end, getY = function() return 0 end,
    getModData = function() return { RPGSkillTree = { level = 5 } } end, getZombieKills = function() return 0 end }
local calls = {}
local xp = { Active = function() return nil end, Start = function(...) calls.xp = {...}; return true end }
local box = { Active = function() return nil end, Start = function(...) calls.box = {...}; return true end }
local drops = { Active = function() return nil end, Start = function(...) calls.drops = {...}; return true end }
local hordeState = { active = false, nextEligibleAt = 15 }
local originalChance = function() return .1 end
local raid = { worldState = function() return hordeState end, chancePercent = originalChance }
function raid.onKill(target)
    equal(raid.chancePercent(), 100, 'guaranteed roll scoped to director start')
    equal(target, p)
    if calls.fail then error('raid failed') end
    return true
end
package.loaded.PRPGE_XPBoostServer = xp
package.loaded.PRPGE_BoxHuntServer = box
package.loaded.PRPGE_DropEventsServer = drops
package.loaded.RPG_Shared_HordeRaid = raid
package.loaded.RPG_Shared_BoxCatalog = { DropBoxes = function() return { { rewards = { { type = 'Base.Axe' } } } } end }
local G = require 'SPDO/Game'
local row = G.ReadPlayer(p, 1)
equal(row.known, true); equal(row.extractionBlock, nil, 'no Extraction Mode must not block')
stats.get = function() return nil end
equal(G.ReadPlayer(p, 1).known, false, 'missing essential stats fail closed')
stats.get = function(_, stat) return stat == 'endurance' and 1 or 0 end
getActivatedMods = function() return { contains = function(_, id) return id == 'ExtractionMode' end } end
equal(G.ReadPlayer(p, 1).extractionBlock, 'ExtractionUnknown')
local root = { playerRaidKeys = { Alice = 'r1' }, raids = { r1 = { state = 'RAID', participants = { Alice = true } } } }
ModData = { get = function() return root end }
ExtractionMode = { Config = { DATA_KEY = 'EM', STATE_RAID = 'RAID', STATE_EXTRACTING = 'EXTRACTING' },
    RaidRuntime = { initialized = true }, RaidThreatAuthority = { playerInsideHideoutCell = function() return false end } }
equal(G.ReadPlayer(p, 1).extractionBlock, nil)
for _, state in ipairs({ 'HIDEOUT', 'COUNTDOWN', 'TRANSIT', 'BOARDING' }) do
    root.raids.r1.state = state
    equal(G.ReadPlayer(p, 1).extractionBlock, 'ExtractionProtected')
end
root.raids.r1.state = 'EXTRACTING'
equal(G.ReadPlayer(p, 1).extractionBlock, nil)
root.raids.r1.boardingPending = { Alice = {} }
equal(G.ReadPlayer(p, 1).extractionBlock, 'ExtractionProtected')
root.raids.r1.boardingPending = nil
ExtractionMode.RaidThreatAuthority.playerInsideHideoutCell = function() return true end
equal(G.ReadPlayer(p, 1).extractionBlock, 'ExtractionProtected')
ExtractionMode.RaidRuntime.initialized = false
equal(G.ReadPlayer(p, 1).extractionBlock, 'ExtractionUnknown')
ExtractionMode.RaidRuntime.initialized = true
ExtractionMode.RaidThreatAuthority.playerInsideHideoutCell = function() return false end
ExtractionMode.Util = { username = function() return 'singleplayer' end }
root.playerRaidKeys.singleplayer = 'r1'; root.raids.r1.participants = { singleplayer = true }
equal(G.ReadPlayer(p, 1).extractionBlock, nil, 'native routing name respected')
getNumActivePlayers = function() return 2 end
p.getPlayerNum = function() return 1 end
equal(G.ReadPlayer(p, 2).id, 'Alice#split1', 'split-screen identities remain distinct')
getNumActivePlayers = nil

S.values.HordesEnabled = true
local ready, reason = G.HordeReady()
equal(ready, false); equal(reason, 'HordeCooldown')
equal(G.Start('horde', { ref = p }), false)
equal(hordeState.nextEligibleAt, 15, 'cooldown never cleared')
hordeState.nextEligibleAt = 0
equal(G.Start('horde', { ref = p }), true)
equal(raid.chancePercent, originalChance)
calls.fail = true
local ok = pcall(G.Start, 'horde', { ref = p })
equal(ok, false); equal(raid.chancePercent, originalChance, 'restore chance on exception')
equal(hordeState.nextEligibleAt, 0)
check(G.Start('xp', nil, 1.5, 10)); equal(calls.xp[2], 1.5); equal(calls.xp[3], 10)
check(G.Start('box', nil, 2, 15)); equal(calls.box[2], 2)
check(G.Start('blood', nil, 10, 15)); equal(calls.drops[1], 'blood'); equal(calls.drops[3], 10)
xp.Active = function() return { id = 'admin', endsAt = 999 } end
drops.Active = function(kind) if kind == 'money' then return { id = 'ticket', endsAt = 999 } end end
local active = G.Inspect()
equal(active.xp.id, 'admin'); equal(active.money.id, 'ticket')
xp.Active = function() error('API changed') end
local unavailable
active, unavailable = G.Inspect()
equal(active.money.id, 'ticket'); equal(unavailable[1], 'xp', 'one failing adapter does not break others')
S.values.BankEnabled = true; S.values.BankForgeEnabled = true; S.values.BankClothForgeEnabled = true
local available = G.Available()
equal(#available, 6, 'broken XP excluded, other events remain')
package.loaded.RPG_Shared_BoxCatalog.DropBoxes = function() return {} end
equal(#G.Available(), 5, 'empty box content excluded')
