if isClient and isClient() then return end

local ok, Config = pcall(require, 'SPDO/Config')
if not ok then print('[Survivor PDA Orchestrator] Cannot load settings: ' .. tostring(Config)); return end
local Game = require 'SPDO/Game'
local Director = require 'SPDO/Director'
local SettingsServer = require 'PRPGE_SettingsServer'
local Settings = require 'PRPGE_Settings'
local Night = require 'SPDO/Night'
require 'SPDO/NightSprinters'
local instance, lastWall, lastHours, failures = nil, nil, nil, 0
local requests = setmetatable({}, { __mode = 'k' })
local lastForceAt
local lastUnavailable

local function migrateNightSettings(data)
    if data.nightSettingsMigrated then return end
    SettingsServer.Load()

    local hasNewValues = false
    for _, definition in ipairs(Config.definitions) do
        if definition.key:sub(1, 10) == 'SPDO_Night' then
            if Settings.values[definition.key] ~= nil
                or not Settings.Same(Settings.Sandbox(definition.key), definition.default) then
                hasNewValues = true
                break
            end
        end
    end

    local legacy = SandboxVars and SandboxVars.ViewpointExtractionSupport
    if not hasNewValues and type(legacy) == 'table' then
        local changes = {}
        if type(legacy.NightMode) == 'boolean' then changes.SPDO_NightEventsEnabled = legacy.NightMode end
        for level = 1, 4 do
            local prefix = 'NightLevel' .. level
            local weight = tonumber(legacy[prefix .. 'Weight'])
            local loot = tonumber(legacy[prefix .. 'LootBonus'])
            local sprinters = tonumber(legacy[prefix .. 'SprinterPercentage'])
            if weight then changes['SPDO_' .. prefix .. 'Weight'] = weight end
            if loot then changes['SPDO_' .. prefix .. 'LootBonus'] = loot end
            if sprinters then changes['SPDO_' .. prefix .. 'SprinterPercentage'] = sprinters end
        end
        if next(changes) and not SettingsServer.Commit(changes) then return end
        if next(changes) and getOnlinePlayers and SettingsServer.Respond then
            local players = getOnlinePlayers()
            for i = 0, players:size() - 1 do SettingsServer.Respond(players:get(i)) end
        end
    end

    data.nightSettingsMigrated = true
    if ModData.transmit then ModData.transmit('SurvivorPDAOrchestrator') end
end

local function initialize()
    if not Game.Authority() or not ModData or not ModData.getOrCreate then return end
    local data = ModData.getOrCreate('SurvivorPDAOrchestrator')
    migrateNightSettings(data)
    if not instance or instance.data ~= data then instance = Director.New(Game, Config, data) end
    lastWall, lastHours = nil, nil
end

local function tick()
    if not Game.Authority() or not instance then return end
    local wall, hours = Game.Milliseconds(), Game.Hours()
    if not lastWall or wall < lastWall then lastWall, lastHours = wall, hours; return end
    local delta = (wall - lastWall) / 1000
    if delta < 1 then return end
    local seconds = 0
    if delta <= 5 and hours > lastHours then
        for _, p in ipairs(Game.Players()) do
            if not p:isDead() then seconds = delta; break end
        end
    end
    lastWall, lastHours = wall, hours
    local success, err = pcall(instance.Step, instance, seconds)
    if success then
        failures = 0
        local signature = table.concat(instance.unavailable or {}, ', ')
        if signature ~= lastUnavailable then
            lastUnavailable = signature
            if signature ~= '' then print('[Survivor PDA Orchestrator] Unavailable event adapters: ' .. signature) end
        end
    else
        failures = failures + 1
        instance.data.reason = 'InternalError'
        if failures == 1 then instance:Record('InternalError', nil, nil, tostring(err):sub(1, 180)) end
    end
end

local function request(p, command)
    local allowed = command == 'Get' or command == 'ForceDecision'
        or command == 'StartNightEvent' or command == 'EndNightEvent'
    if not Game.Authority() or not allowed or not p or not SettingsServer.CanEdit(p) then return false end
    if not (isServer and isServer()) and require('PRPGE_Settings').Get('AdminPanelEnabled') ~= true then return false end
    local now = Game.Milliseconds()
    local playerRequests = requests[p] or {}
    local last = playerRequests[command]
    local requestDelay = command == 'Get' and 2000 or 1500
    if last and now >= last and now - last < requestDelay then return false end
    playerRequests[command] = now
    requests[p] = playerRequests
    local requestResult
    if command == 'ForceDecision' then
        if lastForceAt and now >= lastForceAt and now - lastForceAt < 5000 then
            requestResult = 'ForceCooldown'
        elseif not instance then
            requestResult = 'Initializing'
        else
            lastForceAt = now
            local called, accepted, result = pcall(instance.ForceDecision, instance)
            if called then requestResult = result or instance.data.forceResult
            else
                requestResult = 'InternalError'
                instance.data.reason = 'InternalError'
                if failures == 0 then instance:Record('InternalError', nil, nil, tostring(accepted):sub(1, 180)) end
            end
        end
    elseif command == 'StartNightEvent' or command == 'EndNightEvent' then
        local action = command == 'StartNightEvent' and Night.StartManual or Night.EndManual
        local called, accepted, result = pcall(action)
        if called then
            requestResult = result or (accepted and 'NightStarted' or 'NightUnavailable')
        else
            requestResult = 'InternalError'
            print('[Survivor PDA Orchestrator] Manual Night Event action failed: ' .. tostring(accepted))
        end
    end
    local snapshot
    if instance then
        local success, value = pcall(instance.Snapshot, instance)
        snapshot = success and value or { reason = 'InternalError', detail = tostring(value):sub(1, 180) }
    else snapshot = { reason = 'Initializing' } end
    if requestResult then snapshot.requestResult = requestResult end
    if command == 'StartNightEvent' or command == 'EndNightEvent' then snapshot.nightResult = requestResult end
    local statusOK, nightStatus = pcall(Night.Status)
    if statusOK then snapshot.night = nightStatus end
    if isServer and isServer() then sendServerCommand(p, 'SPDO', 'Snapshot', snapshot)
    elseif triggerEvent then triggerEvent('OnServerCommand', 'SPDO', 'Snapshot', snapshot) end
    return true
end

SPDO_Request = function(p, command)
    if (isClient and isClient()) or (isServer and isServer()) or (isMultiplayer and isMultiplayer()) then return false end
    return request(p, command)
end

if Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(initialize) end
if Events.OnGameStart then Events.OnGameStart.Add(initialize) end
if Events.OnServerStarted then Events.OnServerStarted.Add(initialize) end
if Events.OnClientCommand then
    Events.OnClientCommand.Add(function(module, command, p)
        if module == 'SPDO' then request(p, command) end
    end)
end
if Events.OnPlayerDeath then
    Events.OnPlayerDeath.Add(function(p)
        if not Game.Authority() or not instance or not Config.Get('Enabled') then return end
        instance:Recovery('DeathRecovery')
        for _, sample in pairs(instance.samples) do if sample.ref == p then sample.alive = false end end
    end)
end
require('PRPGE_Tick').Add(tick, 1, 'SurvivorPDAOrchestrator')
