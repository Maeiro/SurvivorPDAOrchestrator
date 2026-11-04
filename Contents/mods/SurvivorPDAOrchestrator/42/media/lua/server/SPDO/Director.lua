local Policy = require 'SPDO/Policy'
local Adaptive = require 'SPDO/Adaptive'
local D = {}
D.__index = D

function D.New(game, config, data)
    data.elapsed = tonumber(data.elapsed) or 0
    data.recoveryUntil = tonumber(data.recoveryUntil) or 0
    data.history = data.history or {}
    data.lastTargets = data.lastTargets or {}
    data.tension = data.tension or {}
    data.opportunities = data.opportunities or {}
    data.pressures = data.pressures or {}
    return setmetatable({ game = game, config = config, data = data, samples = {}, decisionAt = 0, blocked = {} }, D)
end

function D:Record(reason, kind, target, detail)
    local s = self.data
    s.reason = reason
    local row = { at = s.elapsed, worldHour = self.game.Hours(), reason = reason, event = kind, target = target, detail = detail }
    s.history[#s.history + 1] = row
    while #s.history > 20 do table.remove(s.history, 1) end
    print('[Survivor PDA Orchestrator] ' .. reason .. (kind and ' event=' .. kind or '')
        .. (target and ' target=' .. target or '') .. (detail and ' detail=' .. detail or ''))
end

function D:Schedule()
    local low, high = self.config.Interval()
    self.data.nextAt = self.data.elapsed + (low + self.game.Random(high - low + 1)) * 60
end

function D:Retry(reason, detail)
    self.data.nextAt = self.data.elapsed + self.config.Get('RetryMinutes') * 60
    self:Record(reason, nil, nil, detail)
end

function D:Recovery(reason)
    self.data.recoveryUntil = math.max(self.data.recoveryUntil, self.data.elapsed + self.config.Get('RecoveryMinutes') * 60)
    self:Record(reason)
end

function D:Observe(raw)
    local players, present, now = {}, {}, self.data.elapsed
    for _, p in ipairs(raw) do
        present[p.id] = true
        local old = self.samples[p.id]
        if not old or old.ref ~= p.ref then old = { ref = p.ref, joinedAt = now, kills = p.kills, killWindow = {} } end
        local memory = self.data.tension[p.id] or {}
        self.data.tension[p.id] = memory
        local damage = Adaptive.Observe(p, old, memory, now, self.config.Get)
        local own = self.data.own
        local member = own and own.cohort and own.cohort[p.id]
        if member then
            if not p.known or not self.cohortRefs or self.cohortRefs[p.id] ~= p.ref then own.uncertain = true end
            own.damage = (own.damage or 0) + damage
            if p.dead then own.casualty = true end
        end
        if p.dead and old.alive then self:Recovery('DeathRecovery') end
        if damage > 0 then self.data.lastPressureAt = now end
        if p.health and old.health and p.health < old.health then old.damageAt = now end
        if p.kills and old.kills and p.kills > old.kills then
            old.killWindow[#old.killWindow + 1] = { at = now, count = p.kills - old.kills }
        end
        old.kills, old.health, old.alive = p.kills, p.health, not p.dead
        local recent = 0
        for i = #old.killWindow, 1, -1 do
            local k = old.killWindow[i]
            if now - k.at >= 300 then table.remove(old.killWindow, i) else recent = recent + k.count end
        end
        p.joinedAt, p.damageAt, p.recentKills = old.joinedAt, old.damageAt, recent
        if self.config.Get('KillThreshold') > 0 and recent >= self.config.Get('KillThreshold') then self.data.lastPressureAt = now end
        self.samples[p.id] = old
        if not p.dead then players[#players + 1] = p end
    end
    for id in pairs(self.samples) do if not present[id] then self.samples[id] = nil end end
    if self.config.Get('AdaptiveEnabled') then
        Adaptive.Groups(players, self.config.Get('GroupRadius'), self.data.lastTargets, now, self.config.Get('GroupRest'), self.data.pressures)
    end
    self.players = players
    return players
end

function D:ReadPlayers()
    local out = {}
    for i, p in ipairs(self.game.Players()) do out[#out + 1] = self.game.ReadPlayer(p, i) end
    return self:Observe(out)
end

function D:Events(active)
    local s = self.data
    if active.horde then s.lastPressureAt = s.elapsed end
    if s.hordeObserved and not active.horde then self:Recovery('HordeRecovery') end
    s.hordeObserved = active.horde ~= nil
    if s.own then
        local current = active[s.own.kind]
        if s.own.kind == 'horde' then
            for kind in pairs(active) do if kind ~= 'horde' then s.own.uncertain = true end end
            if (self.game.World().nightSprinters or 0) > 0 then s.own.uncertain = true end
        end
        if not current or (s.own.id and current.id ~= s.own.id) then
            if s.own.kind == 'horde' and s.own.cohort then
                local own = s.own
                local missing = current ~= nil or own.uncertain
                for _, kind in ipairs(self.unavailable or {}) do if kind == 'horde' then missing = true end end
                for id, member in pairs(own.cohort) do
                    local sample = self.samples[id]
                    if not sample or not self.cohortRefs or sample.ref ~= self.cohortRefs[id] then missing = true end
                end
                local outcome = missing and 'OutcomeUncertain' or (own.casualty or (own.damage or 0) >= 30) and 'OutcomeSevere' or 'OutcomeManageable'
                if self.config.Get('AdaptiveEnabled') and not missing then
                    for id in pairs(own.cohort) do
                        local pressure = s.pressures[id] or 1
                        s.pressures[id] = outcome == 'OutcomeSevere' and math.max(0.5, pressure * 0.75)
                            or math.min(1, pressure + 0.05)
                    end
                end
                s.lastOutcome = outcome
                self:Record(outcome, 'horde')
            end
            self:Record('EventFinished', s.own.kind)
            s.own = nil
            self.cohortRefs = nil
            self:Schedule()
        end
    end
end

function D:Evaluate(players, random)
    local s, get = self.data, self.config.Get
    local world = self.game.World()
    local context = Adaptive.Context(players, world, s, s.elapsed, get)
    local available, allowed = self.game.Available(), {}
    for _, kind in ipairs(available) do allowed[kind] = true end
    for kind in pairs(context.weights) do
        if not allowed[kind] or not get(kind .. '_Enabled') then context.weights[kind] = 0 end
    end
    if get('Enabled') ~= true then return nil, nil, 'Disabled', context end
    if #players == 0 then return nil, nil, 'NoPlayers', context end
    local active = self.game.Inspect()
    for _ in pairs(active) do return nil, nil, 'ActiveEvent', context end
    if s.own then return nil, nil, 'DirectorEvent', context end
    if s.elapsed < s.recoveryUntil then return nil, nil, 'Recovery', context end
    local target, blocked = Policy.Target(players, s.elapsed, get, s.lastTargets)
    context.blocked = blocked
    local ready, reason = self.game.HordeReady()
    if world.known == false then ready, reason = false, 'Incompatible' end
    if get('AdaptiveEnabled') and target then
        context.pressure = target.pressure or 1
        context.chance = context.chance * context.pressure * (1 - (target.tension or 0) / 100)
    end
    context.target = target and target.id
    context.threatBlock = not target and 'NoSafeTarget' or not ready and reason or nil
    if target and ready and random(10000) < context.chance * 100 then return 'horde', target, 'ThreatStarted', context end
    if context.capped then return nil, nil, 'OpportunityBudget', context end
    local kind = Policy.Opportunity(available, s.lastOpportunity, get, random, context.weights)
    return kind, target, kind and 'OpportunityStarted' or 'NoEligibleEvent', context
end

function D:Simulate()
    local seed = math.floor(self.data.elapsed * 1000) % 2147483646 + 1
    local function random(limit)
        seed = seed * 16807 % 2147483647
        return seed % limit
    end
    local kind, target, reason, context = self:Evaluate(self.players or {}, random)
    context.event, context.target, context.reason = kind, target and target.id, reason
    return context
end

function D:Decide()
    local s, get = self.data, self.config.Get
    local players = self:ReadPlayers()
    local kind, target, reason, context = self:Evaluate(players, self.game.Random)
    self.blocked = context.blocked or {}
    if not kind then
        self:Retry(reason, context.threatBlock)
        s.history[#s.history].context = context
        return
    end

    if kind == 'horde' then
        -- Never use the earlier snapshot to authorize an attack.
        local current, currentBlocked = Policy.Target(self:ReadPlayers(), s.elapsed, get, s.lastTargets)
        self.blocked = currentBlocked
        if not current or current.id ~= target.id then self:Retry('TargetChanged'); return end
        target = current
    end
    local current = self.game.Inspect()
    for _ in pairs(current) do self:Retry('ActiveEvent'); return end
    local minutes, value
    if kind ~= 'horde' then
        local a, b = get(kind .. '_DurationMin'), get(kind .. '_DurationMax')
        local low, high = math.min(a, b), math.max(a, b)
        minutes = low + self.game.Random(high - low + 1)
        value = get(kind .. '_Value')
    end
    local ok, started = pcall(self.game.Start, kind, target, value, minutes)
    if not ok or not started then self:Retry('StartFailed', ok and kind or tostring(started):sub(1, 180)); return end
    s.own = { kind = kind }
    if kind == 'horde' then
        s.own.cohort = {}
        for _, p in ipairs(self.players) do
            if p.id == target.id or (get('AdaptiveEnabled') and p.group == target.group) then
                s.lastTargets[p.id] = s.elapsed
                s.own.cohort[p.id] = true
                self.cohortRefs = self.cohortRefs or {}
                self.cohortRefs[p.id] = p.ref
            end
        end
        s.lastPressureAt = s.elapsed
    else
        s.lastOpportunity = kind
        for i = #s.opportunities, 1, -1 do if s.elapsed - s.opportunities[i] >= 86400 then table.remove(s.opportunities, i) end end
        s.opportunities[#s.opportunities + 1] = s.elapsed
    end
    self:Record(kind == 'horde' and 'ThreatStarted' or 'OpportunityStarted', kind, kind == 'horde' and target.id or nil)
    s.history[#s.history].context = context
    local running = self.game.Inspect()
    if running[kind] then s.own.id = running[kind].id end
end

function D:ForceDecision()
    if self.config.Get('Enabled') ~= true then
        self.data.forceResult = 'Disabled'
        return false, self.data.forceResult
    end
    self.decisionAt = self.data.elapsed + 30
    self:ReadPlayers()
    local active, unavailable = self.game.Inspect()
    self.active, self.unavailable = active, unavailable
    self:Events(active)
    self:Decide()
    local latest = self.data.history[#self.data.history]
    self.data.forceResult = latest and latest.reason or self.data.reason or 'Waiting'
    return true, self.data.forceResult
end

function D:Step(seconds)
    local s, get = self.data, self.config.Get
    local enabled = get('Enabled') == true
    self:ReadPlayers()
    if enabled and #self.players > 0 then s.elapsed = s.elapsed + seconds end
    local active, unavailable = self.game.Inspect()
    self.active, self.unavailable = active, unavailable
    self:Events(active)
    if not enabled then s.reason = 'Disabled'; return end
    local low, high = self.config.Interval()
    local signature = tostring(low) .. ':' .. tostring(high)
    if not s.nextAt or (s.intervalSignature and s.intervalSignature ~= signature and not s.own) then self:Schedule() end
    s.intervalSignature = signature
    if #self.players == 0 then s.reason = 'NoPlayers'; return end
    if s.own then s.reason = 'DirectorEvent'; return end
    if s.elapsed < (s.nextAt or 0) then
        s.reason = s.elapsed < s.recoveryUntil and 'Recovery' or 'Waiting'
        return
    end
    if s.elapsed >= self.decisionAt then self.decisionAt = s.elapsed + 30; self:Decide() end
end

function D:Snapshot()
    local s = self.data
    local world = self.game.World()
    local _, blocked = Policy.Target(self.players or {}, s.elapsed, self.config.Get, s.lastTargets)
    return {
        enabled = self.config.Get('Enabled') == true, elapsed = s.elapsed,
        remaining = math.max(0, (s.nextAt or s.elapsed) - s.elapsed),
        recovery = math.max(0, s.recoveryUntil - s.elapsed), reason = s.reason or 'Waiting',
        forceResult = s.forceResult,
        evaluation = self:Simulate(), lastOutcome = s.lastOutcome,
        active = self.active or {}, unavailable = self.unavailable or {}, blocked = blocked,
        history = s.history, stage = world.stage, hour = world.hour, players = #(self.players or {}),
    }
end

return D
