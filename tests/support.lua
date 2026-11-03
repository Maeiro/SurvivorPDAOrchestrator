local S = { DEFS = {}, BY_KEY = {}, values = {} }
function S.Get(key)
    if S.values[key] ~= nil then return S.values[key] end
    return S.BY_KEY[key] and S.BY_KEY[key].default
end
package.loaded.PRPGE_Settings = S
package.loaded.PRPGE_SettingsLayout = { SECTIONS = {}, BY_ID = {}, FALLBACK = {} }
local C = require 'SPDO/Config'
function set(name, value) S.values['SPDO_' .. name] = value end
function check(value, message) assert(value, message); TEST_COUNT = TEST_COUNT + 1 end
function equal(a, b, message) check(a == b, (message or '') .. ' expected ' .. tostring(b) .. ', got ' .. tostring(a)) end
function player(id, x)
    return { ref = {}, id = id or 'Alice', known = true, dead = false, health = 100, endurance = 1,
        fatigue = 0, bleeding = false, sleeping = false, vehicle = false, kills = 0,
        level = 1, x = x or 0, y = 0, joinedAt = 0, recentKills = 0 }
end
function fixture(saved)
    local G = { rows = { player() }, active = {}, started = {}, available = { 'xp', 'money' }, ready = true,
        world = { stage = 1, hour = 12 }, nextRandom = 0 }
    function G.Random(n) local v = math.min(G.nextRandom, n - 1); G.nextRandom = 0; return v end
    function G.Hours() return 24 end
    function G.Players() return G.rows end
    function G.ReadPlayer(p) local copy = {}; for k,v in pairs(p) do copy[k] = v end; return copy end
    function G.Inspect() return G.active, {} end
    function G.World() return G.world end
    function G.Available() return G.available end
    function G.HordeReady() return G.ready, 'HordeCooldown' end
    function G.Start(kind, target, value, minutes)
        G.started[#G.started + 1] = { kind = kind, target = target, value = value, minutes = minutes }
        if G.fail then error('native failure') end
        G.active[kind] = { id = 'one' }
        return true
    end
    local D = require('SPDO/Director').New(G, C, saved or {})
    return D, G, C, S
end
return { config = C, settings = S }
