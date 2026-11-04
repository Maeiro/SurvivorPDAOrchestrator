local P = {}

function P.Blocker(player, now, get)
    if not player.known then return 'UnknownPlayerState' end
    if get('AdaptiveEnabled') and (player.tension or 0) >= get('TensionLimit') then return 'HighTension' end
    if get('AdaptiveEnabled') and player.groupRestUntil and now < player.groupRestUntil then return 'GroupRest' end
    if player.health < get('HealthMin') then return 'LowHealth' end
    if player.endurance * 100 < get('EnduranceMin') then return 'LowEndurance' end
    if player.fatigue * 100 > get('FatigueMax') then return 'HighFatigue' end
    if get('BlockBleeding') and player.bleeding then return 'Bleeding' end
    if get('BlockSleeping') and player.sleeping then return 'Sleeping' end
    if get('BlockVehicles') and player.vehicle then return 'Vehicle' end
    if now - player.joinedAt < get('JoinGrace') * 60 then return 'JoinGrace' end
    if player.damageAt and now - player.damageAt < get('DamageGrace') * 60 then return 'RecentDamage' end
    if get('KillThreshold') > 0 and player.recentKills >= get('KillThreshold') then return 'IntenseCombat' end
    if get('ExtractionProtection') and player.extractionBlock then return player.extractionBlock end
end

function P.Target(players, now, get, lastTargets)
    local candidates, blocked = {}, {}
    for _, p in ipairs(players) do
        local reason = P.Blocker(p, now, get)
        if not reason then
            for _, other in ipairs(players) do
                if other.id ~= p.id and get('NeighborRadius') > 0 then
                    local near = not p.x or not p.y or not other.x or not other.y
                    if not near then
                        local dx, dy = p.x - other.x, p.y - other.y
                        near = dx * dx + dy * dy <= get('NeighborRadius') ^ 2
                    end
                    if near and P.Blocker(other, now, get) then reason = 'VulnerableNeighbor'; break end
                end
            end
        end
        if reason then blocked[#blocked + 1] = { player = p.id, reason = reason }
        else candidates[#candidates + 1] = p end
    end
    table.sort(candidates, function(a, b)
        local aa, bb = a.groupLastTarget or lastTargets[a.id] or -1, b.groupLastTarget or lastTargets[b.id] or -1
        if aa == bb then
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return a.id < b.id
        end
        return aa < bb
    end)
    return candidates[1], blocked
end

function P.Opportunity(available, last, get, random, weights)
    local function weight(kind) return weights and weights[kind] or get(kind .. '_Weight') end
    local pool, total = {}, 0
    for _, kind in ipairs(available) do
        if get(kind .. '_Enabled') and weight(kind) > 0 then pool[#pool + 1] = kind end
    end
    if #pool > 1 then
        for i = #pool, 1, -1 do if pool[i] == last then table.remove(pool, i) end end
    end
    for _, kind in ipairs(pool) do total = total + weight(kind) end
    if total == 0 then return nil end
    local roll = random(total)
    for _, kind in ipairs(pool) do
        roll = roll - weight(kind)
        if roll < 0 then return kind end
    end
end

return P
