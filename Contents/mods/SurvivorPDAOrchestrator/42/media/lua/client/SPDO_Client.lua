local ok, Config = pcall(require, 'SPDO/Config')
if not ok then return end
local okPanel, Panel = pcall(require, 'PRPGE_AdminConsole')
if not okPanel or type(Panel.DRAW) ~= 'table' or type(Panel.DRAW.settings) ~= 'function'
    or type(Panel.SECTIONS) ~= 'table' or type(Panel.SEC) ~= 'table'
    or type(Panel.key) ~= 'function' or type(Panel.settingRow) ~= 'function' or type(Panel.list) ~= 'function' then
    print('[Survivor PDA Orchestrator] PDA Admin interface incompatible; use sandbox options.')
    return
end
local Text = require 'SPDO/Locale'
local Settings = require 'PRPGE_Settings'
local Skin = require 'PRPGE_Skin'
local snapshot, receivedAt, requestedAt = nil, 0, {}
local T = Text.Text

local function clock(seconds)
    seconds = math.max(0, math.ceil(seconds or 0))
    return string.format('%02d:%02d:%02d', math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function request(self, command)
    command = command or 'Get'
    local now = getTimestampMs()
    local delay = command == 'Get' and 5000 or 3000
    local last = requestedAt[command] or -1e9
    if now >= last and now - last < delay then return false end
    requestedAt[command] = now
    local p = self.player or getSpecificPlayer(0)
    if not p then return false end
    if isClient and isClient() then sendClientCommand(p, 'SPDO', command, {})
    elseif SPDO_Request then SPDO_Request(p, command) end
    return true
end

local function diagnostic(self, r)
    request(self)
    local rows = {}
    local function row(label, value) rows[#rows + 1] = label .. (value and ': ' .. tostring(value) or '') end
    if not snapshot then row(T('Initializing'))
    else
        if getTimestampMs() - receivedAt > 15000 then row(T('Stale')) end
        row(T('State'), T(snapshot.reason or 'Waiting'))
        if snapshot.forceResult then row(T('LastForcedDecision'), T(snapshot.forceResult)) end
        if snapshot.requestResult then row(T('ForceRequest'), T(snapshot.requestResult)) end
        row(T('NextDecision'), clock(snapshot.remaining))
        row(T('RecoveryTime'), clock(snapshot.recovery))
        row(T('Players'), snapshot.players or 0)
        row(T('WorldDanger'), tostring(snapshot.stage or 1) .. ' / 5')
        row(T('WorldTime'), string.format('%.2f', snapshot.hour or 0))
        row(T('NativeClock'))
        row(T('NativeHordes'))
        for kind in pairs(snapshot.active or {}) do row(T('Running'), T('Event_' .. kind)) end
        for _, kind in ipairs(snapshot.unavailable or {}) do row(T('Incompatible'), T('Event_' .. kind)) end
        for _, blocked in ipairs(snapshot.blocked or {}) do row(blocked.player, T(blocked.reason)) end
        if snapshot.detail then row(snapshot.detail) end
        row(T('History'))
        local history = snapshot.history or {}
        for i = #history, 1, -1 do
            local h = history[i]
            local value = '[' .. clock(h.at) .. '] ' .. T(h.reason)
            if h.event then value = value .. ' - ' .. T('Event_' .. h.event) end
            if h.target then value = value .. ' - ' .. h.target end
            row(value)
            if h.detail then row('  ' .. (h.detail == 'NoSafeTarget' and T(h.detail) or h.detail)) end
        end
    end
    self:list('spdoDiagnostic', r, #rows, 32, function(i, rr)
        self:text(rows[i], rr.x + 8, rr.y + 5, Skin.TEXT, UIFont.Small, rr.w - 16)
    end)
end

if not Panel._spdoSection then
    local found = false
    for _, section in ipairs(Panel.SECTIONS) do if section == 'orchestrator' then found = true end end
    if not found then table.insert(Panel.SECTIONS, 2, 'orchestrator') end
    Panel.SEC.orchestrator = { 'SPDO_Title', 'ORCHESTRATOR', 'CZStar' }
    Panel.DRAW.orchestrator = function(self, r)
        local tabs = { 'Diagnostics', 'General', 'Protection', 'Events', 'NightEvents' }
        self.spdoTab = self.spdoTab or 1
        local tabWidth = math.floor((r.w - 24) / 5)
        for i, tab in ipairs(tabs) do
            self:key({ x = r.x + (i - 1) * (tabWidth + 6), y = r.y, w = tabWidth, h = 36 }, T(tab),
                function() self.spdoTab = i; self.scroll.spdoConfig = 0; self.scroll.spdoNightConfig = 0 end,
                self.spdoTab == i and 'on' or nil, nil, nil, 'spdoTab' .. i)
        end
        local area = { x = r.x, y = r.y + 44, w = r.w, h = r.h - 44 }
        if self.spdoTab == 1 then
            self:key({ x = area.x, y = area.y, w = 260, h = 36 }, T('DecideNow'), function()
                request(self, 'ForceDecision')
            end, 'gold', 'CZStar', T('ForceDecisionTip'), 'spdoForceDecision')
            diagnostic(self, { x = area.x, y = area.y + 44, w = area.w, h = area.h - 44 })
            return
        end
        if self.spdoTab == 5 then
            request(self)
            local buttonWidth = math.floor((area.w - 8) / 2)
            self:key({ x = area.x, y = area.y, w = buttonWidth, h = 36 }, T('StartNightEvent'), function()
                request(self, 'StartNightEvent')
            end, 'gold', nil, T('StartNightEventTip'), 'spdoStartNightEvent')
            self:key({ x = area.x + buttonWidth + 8, y = area.y, w = buttonWidth, h = 36 }, T('EndNightEvent'), function()
                request(self, 'EndNightEvent')
            end, 'red', nil, T('EndNightEventTip'), 'spdoEndNightEvent')
            local night = snapshot and snapshot.night
            local status = T('Initializing')
            if night then
                if night.active then status = string.format(T('NightStatusActive'), tonumber(night.level) or 1)
                elseif not night.enabled then status = T('NightStatusDisabled')
                elseif not night.isNight then status = T('NightStatusDay')
                else status = T('NightStatusInactive') end
            end
            self:text(T('NightEventStatus') .. ': ' .. status, area.x + 4, area.y + 42, Skin.TEXT, UIFont.Small, area.w - 8)
            if snapshot and snapshot.nightResult then
                self:text(T(snapshot.nightResult), area.x + 4, area.y + 62, Skin.MUTED, UIFont.Small, area.w - 8)
            end
            local listY = area.y + 88
            local configArea = { x = area.x, y = listY, w = area.w, h = math.max(40, area.y + area.h - listY) }
            local defs = {}
            for _, d in ipairs(Config.definitions) do
                local name = d.key:sub(6)
                if name:sub(1, 5) == 'Night' then defs[#defs + 1] = Settings.BY_KEY[d.key] end
            end
            self:list('spdoNightConfig', configArea, #defs, 40, function(i, rr) self:settingRow(defs[i], rr) end)
            return
        end
        local defs = {}
        local protections = { HealthMin = true, EnduranceMin = true, FatigueMax = true, BlockBleeding = true, DamageGrace = true,
            JoinGrace = true, BlockSleeping = true, BlockVehicles = true, NeighborRadius = true, RecoveryMinutes = true,
            KillThreshold = true, ExtractionProtection = true }
        for _, d in ipairs(Config.definitions) do
            local name = d.key:sub(6)
            local category = protections[name] and 3 or name:sub(1, 5) == 'Night' and 5
                or (name:find('_') or name:find('ThreatChance') or name == 'HordeEnabled' or name == 'NightThreatMultiplier') and 4 or 2
            if category == self.spdoTab then defs[#defs + 1] = Settings.BY_KEY[d.key] end
        end
        self:list('spdoConfig', area, #defs, 40, function(i, rr) self:settingRow(defs[i], rr) end)
    end
    Panel._spdoSection = true
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command, args)
        if module == 'SPDO' and command == 'Snapshot' and type(args) == 'table' then
            snapshot, receivedAt = args, getTimestampMs()
        end
    end)
end
