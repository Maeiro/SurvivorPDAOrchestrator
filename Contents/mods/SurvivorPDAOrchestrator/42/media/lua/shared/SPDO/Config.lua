local Settings = require 'PRPGE_Settings'
local C = { definitions = {}, events = { 'xp', 'money', 'box', 'blood', 'soul', 'marrow', 'bile' } }

local function define(name, value, minimum, maximum, choices)
    local d = { key = 'SPDO_' .. name, group = 'Orchestrator', default = value, min = minimum or 0, max = maximum or 1000 }
    if choices then d.choices = choices end
    if type(value) == 'number' and value ~= math.floor(value) then d.decimal = true end
    C.definitions[#C.definitions + 1] = d
    if not Settings.BY_KEY[d.key] then
        Settings.DEFS[#Settings.DEFS + 1] = d
        Settings.BY_KEY[d.key] = d
    end
end

define('Enabled', false)
define('Preset', 1, 1, 4, { 'SPDO_Rare', 'SPDO_Moderate', 'SPDO_Frequent', 'SPDO_Custom' })
define('IntervalMin', 60, 1, 1440)
define('IntervalMax', 120, 1, 1440)
define('RetryMinutes', 5, 1, 60)
define('HealthMin', 80, 0, 100)
define('EnduranceMin', 60, 0, 100)
define('FatigueMax', 60, 0, 100)
define('BlockBleeding', true)
define('DamageGrace', 10, 0, 120)
define('JoinGrace', 15, 0, 120)
define('BlockSleeping', true)
define('BlockVehicles', true)
define('NeighborRadius', 100, 0, 500)
define('RecoveryMinutes', 20, 0, 240)
define('KillThreshold', 20, 0, 1000)
define('ExtractionProtection', true)
define('AdaptiveEnabled', true)
define('TensionDecay', 3, 1, 20)
define('TensionLimit', 70, 1, 100)
define('GroupRadius', 100, 0, 500)
define('GroupRest', 30, 0, 240)
define('CalmMinutes', 60, 1, 240)
define('OpportunityLimit', 4, 0, 100)
define('OpportunityWindow', 240, 1, 1440)
define('ContextOpportunities', true)
define('HordeEnabled', true)
define('NightThreatMultiplier', 1, 0, 3)
C.definitions[#C.definitions].decimal = true
for stage, chance in ipairs({ 10, 15, 20, 25, 30 }) do define('ThreatChance' .. stage, chance, 0, 100) end
define('NightEventsEnabled', false)
define('NightEventsChance', 50, 0, 100)
local nightLevels = {
    { weight = 50, lootBonus = 50, sprinterPercentage = 10 },
    { weight = 35, lootBonus = 100, sprinterPercentage = 20 },
    { weight = 10, lootBonus = 150, sprinterPercentage = 33 },
    { weight = 5, lootBonus = 200, sprinterPercentage = 50 },
}
for level, values in ipairs(nightLevels) do
    define('NightLevel' .. level .. 'Weight', values.weight, 0, 100)
    define('NightLevel' .. level .. 'LootBonus', values.lootBonus, 0, 500)
    define('NightLevel' .. level .. 'SprinterPercentage', values.sprinterPercentage, 0, 100)
end
local weights = { xp = 25, money = 20, box = 10, blood = 15, soul = 10, marrow = 10, bile = 10 }
for _, kind in ipairs(C.events) do
    define(kind .. '_Enabled', true)
    define(kind .. '_Weight', weights[kind], 0, 1000)
    define(kind .. '_Value', (kind == 'xp' or kind == 'money') and 1.5 or kind == 'box' and 2 or 10,
        (kind == 'xp' or kind == 'money') and 1.1 or 0.5, (kind == 'xp' or kind == 'money') and 10 or 100)
    C.definitions[#C.definitions].decimal = true
    define(kind .. '_DurationMin', 10, 1, 1440)
    define(kind .. '_DurationMax', 15, 1, 1440)
end

function C.Get(name) return Settings.Get('SPDO_' .. name) end
function C.Interval(get)
    get = get or C.Get
    local preset = get('Preset')
    if preset == 1 then return 60, 120 end
    if preset == 2 then return 30, 60 end
    if preset == 3 then return 15, 30 end
    local a, b = get('IntervalMin'), get('IntervalMax')
    return math.min(a, b), math.max(a, b)
end

local ok, layout = pcall(require, 'PRPGE_SettingsLayout')
if ok and type(layout.FALLBACK) == 'table' then
    layout.FALLBACK.Orchestrator = 'OrchestratorAdmin'
end

return C
