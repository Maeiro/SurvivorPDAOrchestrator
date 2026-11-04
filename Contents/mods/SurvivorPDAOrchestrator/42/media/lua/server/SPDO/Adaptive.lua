local A = {}

function A.Observe(p, old, memory, now, get)
    local dt = math.max(0, now - (memory.at or now))
    local damage = p.health and old.health and math.max(0, old.health - p.health) or 0
    local kills = p.kills and old.kills and math.max(0, p.kills - old.kills) or 0
    local floor = p.known and math.min(100, (100 - p.health) * 1.2 + (1 - p.endurance) * 35
        + p.fatigue * 25 + (p.bleeding and 30 or 0)) or 100
    memory.value = math.min(100, math.max(floor, (memory.value or 0) - dt / 60 * get('TensionDecay')
        + damage * 2 + kills * 1.5 + (p.dead and old.alive and 60 or 0)))
    memory.at = now
    p.tension = memory.value
    return damage
end

function A.Groups(players, radius, lastTargets, now, rest, pressures)
    local groups, assigned = {}, {}
    for _, first in ipairs(players) do
        if not assigned[first.id] then
            local group = { first }
            assigned[first.id] = true
            local i = 1
            while i <= #group do
                local p = group[i]
                for _, other in ipairs(players) do
                    if not assigned[other.id] and radius > 0 then
                        local near = not p.x or not p.y or not other.x or not other.y
                        if not near then near = (p.x - other.x)^2 + (p.y - other.y)^2 <= radius^2 end
                        if near then group[#group + 1] = other; assigned[other.id] = true end
                    end
                end
                i = i + 1
            end
            local latest, tension, pressure = nil, 0, 1
            for _, p in ipairs(group) do
                local at = lastTargets[p.id]
                if at then latest = math.max(latest or at, at) end
                tension = math.max(tension, p.tension or 0)
                pressure = math.min(pressure, pressures and pressures[p.id] or 1)
            end
            for _, p in ipairs(group) do
                p.group = first.id
                p.pressure = pressure
                p.tension = tension
                p.groupRestUntil = latest and latest + rest * 60 or nil
                p.groupLastTarget = latest
            end
            groups[#groups + 1] = group
        end
    end
    return groups
end

function A.Context(players, world, data, now, get)
    local maxTension, levels, kills = 0, 0, 0
    for _, p in ipairs(players) do
        maxTension = math.max(maxTension, p.tension or 0)
        levels = levels + (p.level or 1)
        kills = kills + (p.recentKills or 0)
    end
    local night = world.nightSprinters or 0
    local calm = math.min(1, math.max(0, now - (data.lastPressureAt or 0)) / (get('CalmMinutes') * 60))
    local chance = get('ThreatChance' .. world.stage)
    if world.hour < 6 or world.hour >= 20 then chance = chance * get('NightThreatMultiplier') end
    if get('AdaptiveEnabled') then
        chance = chance * (0.6 + 0.4 * calm) * (1 - night / 100)
    end
    local weights = {}
    for _, kind in ipairs({ 'xp', 'money', 'box', 'blood', 'soul', 'marrow', 'bile' }) do
        weights[kind] = get(kind .. '_Weight')
    end
    if get('AdaptiveEnabled') and get('ContextOpportunities') and #players > 0 then
        if levels / #players <= 10 then weights.xp = weights.xp * 1.5 end
        if kills > 0 then
            for _, kind in ipairs({ 'money', 'box', 'blood', 'soul', 'marrow', 'bile' }) do weights[kind] = weights[kind] * 1.25 end
        end
    end
    -- Native random APIs take integer limits.
    for kind, value in pairs(weights) do weights[kind] = math.floor(value * 100) end
    local count = 0
    for _, at in ipairs(data.opportunities or {}) do if now - at < get('OpportunityWindow') * 60 then count = count + 1 end end
    return { tension = maxTension, nightSprinters = night, chance = math.min(100, chance), weights = weights,
        pressure = 1, opportunities = count,
        capped = get('AdaptiveEnabled') and get('OpportunityLimit') > 0 and count >= get('OpportunityLimit') }
end

return A
