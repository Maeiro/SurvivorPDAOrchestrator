local Pause = {}
local pausedAt, pausedTotal = nil, 0
local dropKinds = { money = true, blood = true, soul = true, marrow = true, bile = true }

local function singlePlayer()
    return not ((isClient and isClient()) or (isServer and isServer()) or (isMultiplayer and isMultiplayer()))
end

local function shiftDeadline(own, from, now)
    if not own or not own.id or not ModData or not ModData.get then return end
    local kind = own.kind
    local boost, drops = PRPGE_XPBoostClient, PRPGE_DropEventsClient
    local event, hud
    if kind == 'xp' then
        event, hud = ModData.get('PRPGE_XPBoost'), boost and boost.state
    elseif kind == 'box' then
        event, hud = ModData.get('PRPGE_BoxHunt'), boost and boost.hunt
    elseif dropKinds[kind] then
        local events = ModData.get('PRPGE_DropEvents')
        event = events and events[kind]
        hud = drops and drops.drops and drops.drops[kind]
    end
    if not event or event.id ~= own.id then return end
    local endsAt = tonumber(event.endsAt)
    local since = math.max(from, tonumber(event.startedAt) or from)
    if not endsAt or endsAt <= since or now <= since then return end

    -- SP runs both native event logic and HUD in this Lua state.
    event.endsAt = endsAt + (now - since)
    if hud and hud.id == own.id then hud.endsAt = event.endsAt end
end

function Pause.Reset()
    pausedAt, pausedTotal = nil, 0
end

function Pause.Update(own)
    if not singlePlayer() or not isGamePaused then return end
    local paused = isGamePaused()
    if not paused and not pausedAt then return end
    local now = getTimestampMs()
    if pausedAt and now > pausedAt then
        pausedTotal = pausedTotal + (now - pausedAt)
        shiftDeadline(own, pausedAt, now)
    end
    pausedAt = paused and now or nil
end

function Pause.PlayedClock(wall)
    if not singlePlayer() then return wall end
    if isGamePaused and isGamePaused() then return nil end
    return wall - pausedTotal
end

return Pause
