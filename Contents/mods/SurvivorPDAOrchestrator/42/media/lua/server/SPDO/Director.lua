local Policy = require 'SPDO/Policy'
local D = {}
D.__index = D

function D.New(game, config, data)
    data.elapsed = tonumber(data.elapsed) or 0
    data.recoveryUntil = tonumber(data.recoveryUntil) or 0
    data.history = data.history or {}
    data.lastTargets = data.lastTargets or {}
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
        if p.dead and old.alive then self:Recovery('DeathRecovery') end
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
        self.samples[p.id] = old
        if not p.dead then players[#players + 1] = p end
    end
    for id in pairs(self.samples) do if not present[id] then self.samples[id] = nil end end
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
    if s.hordeObserved and not active.horde then self:Recovery('HordeRecovery') end
    s.hordeObserved = active.horde ~= nil
    if s.own then
        local current = active[s.own.kind]
        if not current or (s.own.id and current.id ~= s.own.id) then
            self:Record('EventFinished', s.own.kind)
            s.own = nil
            self:Schedule()
        end
    end
end

function D:Decide()
    local s, get = self.data, self.config.Get
    local players = self:ReadPlayers()
    if #players == 0 then self:Retry('NoPlayers'); return end
    local active, unavailable = self.game.Inspect()
    self.unavailable = unavailable
    for _ in pairs(active) do self:Retry('ActiveEvent'); return end
    if s.elapsed < s.recoveryUntil then self:Retry('Recovery'); return end

    local target, blocked = Policy.Target(players, s.elapsed, get, s.lastTargets)
    self.blocked = blocked
    local world = self.game.World()
    local hordeReady, hordeReason = self.game.HordeReady()
    if world.known == false then hordeReady, hordeReason = false, 'Incompatible' end
    local chance = get('ThreatChance' .. world.stage)
    if world.hour < 6 or world.hour >= 20 then chance = chance * get('NightThreatMultiplier') end
    local kind
    if target and hordeReady and self.game.Random(10000) < math.min(100, chance) * 100 then kind = 'horde' end
    if not kind then kind = Policy.Opportunity(self.game.Available(), s.lastOpportunity, get, self.game.Random) end
    if not kind then
        self:Retry('NoEligibleEvent', not target and 'NoSafeTarget' or hordeReason)
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
    if kind == 'horde' then s.lastTargets[target.id] = s.elapsed else s.lastOpportunity = kind end
    self:Record(kind == 'horde' and 'ThreatStarted' or 'OpportunityStarted', kind, kind == 'horde' and target.id or nil)
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
        active = self.active or {}, unavailable = self.unavailable or {}, blocked = blocked,
        history = s.history, stage = world.stage, hour = world.hour, players = #(self.players or {}),
    }
end

return D
