local G = {}
local Settings = require 'PRPGE_Settings'
local Config = require 'SPDO/Config'
local modules = {}
local names = { xp = 'PRPGE_XPBoostServer', box = 'PRPGE_BoxHuntServer', drops = 'PRPGE_DropEventsServer', horde = 'RPG_Shared_HordeRaid' }

local function module(kind)
    if modules[kind] == nil then
        local ok, value = pcall(require, names[kind])
        modules[kind] = ok and type(value) == 'table' and value or false
    end
    return modules[kind] or nil
end

local function call(object, method, ...)
    if not object or type(object[method]) ~= 'function' then return nil, false end
    local ok, value = pcall(object[method], object, ...)
    return value, ok
end

local function number(value)
    if type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge then return value end
end

function G.Authority() return not (isClient and isClient()) end
function G.Milliseconds() return getTimestampMs() end
function G.Hours() return getGameTime():getWorldAgeHours() end
function G.Random(limit) return ZombRand(limit) end

function G.Players()
    local out = {}
    if isServer and isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do out[#out + 1] = players:get(i) end
    else
        local n = getNumActivePlayers and getNumActivePlayers() or 1
        for i = 0, n - 1 do
            local p = getSpecificPlayer(i)
            if p then out[#out + 1] = p end
        end
    end
    return out
end

local function extractionBlock(p, id)
    local em = ExtractionMode
    local installed = em ~= nil
    if not installed and getActivatedMods then
        local mods = getActivatedMods()
        installed = mods and (mods:contains('ExtractionMode') or mods:contains('\\ExtractionMode'))
    end
    if not installed then return nil end
    if not em or not em.Config or not em.RaidRuntime or not em.RaidRuntime.initialized
        or not em.RaidThreatAuthority or type(em.RaidThreatAuthority.playerInsideHideoutCell) ~= 'function' then
        return 'ExtractionUnknown'
    end
    if em.RaidThreatAuthority.playerInsideHideoutCell(p) then return 'ExtractionProtected' end
    local routeId = em.Util and type(em.Util.username) == 'function' and em.Util.username(p) or id
    local root = ModData.get(em.Config.DATA_KEY)
    local key = root and root.playerRaidKeys and root.playerRaidKeys[routeId]
    local raid = key and root.raids and root.raids[key]
    if not raid then return 'ExtractionUnknown' end
    if raid.state ~= em.Config.STATE_RAID and raid.state ~= em.Config.STATE_EXTRACTING then return 'ExtractionProtected' end
    if type(raid.participants) ~= 'table' or not raid.participants[routeId] then return 'ExtractionUnknown' end
    for _, field in ipairs({ 'boardingPending', 'returnPending', 'groundExtractionPending', 'lateJoinPending', 'lateInsertionCleanup', 'deathRescuePending', 'raidReconnectPending' }) do
        if type(raid[field]) == 'table' and raid[field][routeId] ~= nil then return 'ExtractionProtected' end
    end
    if raid.campaignHandoff or raid.vehicleInsertion then return 'ExtractionProtected' end
end

function G.ReadPlayer(p, index)
    local id = call(p, 'getUsername')
    if type(id) ~= 'string' or id == '' then id = '__SP__' .. tostring(index) end
    if not (isServer and isServer()) and not (isClient and isClient()) and getNumActivePlayers and getNumActivePlayers() > 1 then
        local slot = number(call(p, 'getPlayerNum')) or index - 1
        if slot > 0 then id = id .. '#split' .. tostring(slot) end
    end
    local dead, deadKnown = call(p, 'isDead')
    local body = call(p, 'getBodyDamage')
    local stats = call(p, 'getStats')
    local health = number(call(body, 'getHealth'))
    local bleeding = number(call(body, 'getNumPartsBleeding'))
    local endurance = CharacterStat and number(call(stats, 'get', CharacterStat.ENDURANCE))
    local fatigue = CharacterStat and number(call(stats, 'get', CharacterStat.FATIGUE))
    local sleeping, sleepKnown = call(p, 'isAsleep')
    local vehicle, vehicleKnown = call(p, 'getVehicle')
    local x, y = number(call(p, 'getX')), number(call(p, 'getY'))
    local data = call(p, 'getModData')
    local level = data and data.RPGSkillTree and number(data.RPGSkillTree.level)
    local kills = number(call(p, 'getZombieKills'))
    local ok, block = pcall(extractionBlock, p, id)
    if not ok then block = 'ExtractionUnknown' end
    return {
        ref = p, id = id, dead = dead == true, deadKnown = deadKnown,
        health = health, endurance = endurance, fatigue = fatigue, bleeding = bleeding and bleeding > 0,
        sleeping = sleeping == true, vehicle = vehicle ~= nil, x = x, y = y, level = level,
        kills = kills, extractionBlock = block,
        known = deadKnown and type(dead) == 'boolean' and sleepKnown and type(sleeping) == 'boolean'
            and vehicleKnown and health ~= nil and health >= 0 and health <= 100
            and endurance ~= nil and endurance >= 0 and endurance <= 1
            and fatigue ~= nil and fatigue >= 0 and fatigue <= 1
            and bleeding ~= nil and x ~= nil and y ~= nil and kills ~= nil,
    }
end

function G.World()
    local ok, danger = pcall(require, 'PRPGE_DangerForce')
    local success, stage = false, nil
    if ok and type(danger.stage) == 'function' then success, stage = pcall(danger.stage) end
    stage = number(stage)
    return { stage = math.max(1, math.min(5, math.floor(stage or 1))), hour = getGameTime():getTimeOfDay(), known = success and stage ~= nil }
end

local function compatible(kind)
    local m = module(kind)
    if kind == 'horde' then return m and type(m.worldState) == 'function' and type(m.onKill) == 'function' and type(m.chancePercent) == 'function' end
    return m and type(m.Active) == 'function' and type(m.Start) == 'function'
end

function G.Inspect()
    local active, unavailable = {}, {}
    for _, kind in ipairs({ 'xp', 'box', 'drops', 'horde' }) do
        if not compatible(kind) then unavailable[#unavailable + 1] = kind
        else
            local m = module(kind)
            local ok, err = pcall(function()
                if kind == 'horde' then
                    local s = m.worldState()
                    if not s then error('Horde state unavailable') end
                    if s.active then active.horde = { id = tostring(s.startsAt) .. ':' .. tostring(s.owner), endsAt = s.endsAt } end
                elseif kind == 'drops' then
                    for _, event in ipairs({ 'money', 'blood', 'soul', 'marrow', 'bile' }) do
                        local s = m.Active(event)
                        if s then active[event] = { id = s.id, endsAt = s.endsAt } end
                    end
                else
                    local s = m.Active()
                    if s then active[kind] = { id = s.id, endsAt = s.endsAt } end
                end
            end)
            if not ok then
                modules[kind] = false
                unavailable[#unavailable + 1] = kind
                print('[Survivor PDA Orchestrator] Disabled adapter ' .. kind .. ': ' .. tostring(err))
            end
        end
    end
    return active, unavailable
end

function G.HordeReady()
    if not Config.Get('HordeEnabled') or Settings.Get('HordesEnabled') ~= true then return false, 'HordesDisabled' end
    if not compatible('horde') then return false, 'Incompatible' end
    local s = module('horde').worldState()
    if not s or s.active then return false, 'ActiveEvent' end
    if G.Hours() < (tonumber(s.nextEligibleAt) or 0) then return false, 'HordeCooldown' end
    return true
end

function G.Available()
    local out = {}
    for _, kind in ipairs(Config.events) do
        local supported = compatible((kind == 'xp' or kind == 'box') and kind or 'drops')
        if kind == 'xp' and Settings.Get('SkillTreeEnabled') ~= true then supported = false end
        if kind == 'money' and Settings.Get('BankEnabled') ~= true then supported = false end
        if (kind == 'blood' or kind == 'soul') and Settings.Get('BankForgeEnabled') ~= true then supported = false end
        if (kind == 'marrow' or kind == 'bile') and Settings.Get('BankClothForgeEnabled') ~= true then supported = false end
        if kind == 'box' and supported then
            local ok, catalog = pcall(require, 'RPG_Shared_BoxCatalog')
            local success, boxes = false, nil
            if ok and type(catalog.DropBoxes) == 'function' then success, boxes = pcall(catalog.DropBoxes, 'hunt') end
            supported = success and type(boxes) == 'table' and #boxes > 0
        end
        if supported then out[#out + 1] = kind end
    end
    return out
end

function G.Start(kind, target, value, minutes)
    if kind == 'horde' then
        local ready = G.HordeReady()
        if not ready then return false end
        local raid = module('horde')
        local original = raid.chancePercent
        -- The native admin action clears the cooldown; the director must preserve it.
        raid.chancePercent = function() return 100 end
        local ok, started = pcall(raid.onKill, target.ref)
        raid.chancePercent = original
        if not ok then error(started) end
        return started == true
    end
    local m = module((kind == 'xp' or kind == 'box') and kind or 'drops')
    if kind == 'xp' or kind == 'box' then return m.Start(nil, value, minutes) end
    return m.Start(kind, nil, value, minutes)
end

return G
