local pending = setmetatable({}, { __mode = 'k' })
local sent = setmetatable({}, { __mode = 'k' })
local nextTick, nextHook = 0, 0
local hooked = {}

local function enqueue(container, player)
    if not container or not player then return end
    local object = container:getParent()
    if not object or object:getObjectIndex() < 0 or container:getContainingItem() or container:getCharacter() then return end
    pending[container] = player
end

local function wrap(class, method, observe)
    if not class or type(class[method]) ~= 'function' then return end
    hooked[class] = hooked[class] or {}
    if hooked[class][method] then return end
    local original = class[method]
    local wrapper = function(self, ...)
        local result = original(self, ...)
        observe(self, ...)
        return result
    end
    hooked[class][method] = true
    class[method] = wrapper
end

local function install()
    wrap(ISInventoryPane, 'render', function(pane)
        if ErgonomicUI and ErgonomicUI.panel and ErgonomicUI.panel.hideVanillaInv then return end
        if ViewpointInvScreen and ViewpointInvScreen.isUp and ViewpointInvScreen.isUp() then return end
        local player = getSpecificPlayer(pane.player or 0)
        local page = getPlayerLoot(pane.player or 0)
        if page and page.inventoryPane == pane and page:getIsVisible() and not page.isCollapsed then
            enqueue(pane.inventory, player)
        end
    end)
    wrap(ErgUIPanel, 'renderSideView', function(panel, side, grid)
        if side ~= 'world' or not grid or (grid.zoneH or 0) <= 0 then return end
        if (panel._panelAlphaNow or 1) <= 0.01 then return end
        local selected = panel.worldContainers and panel.worldContainers[panel.selectedWorldIdx]
        enqueue(selected and selected.inventory, getSpecificPlayer(panel.player or 0))
    end)
    wrap(ViewpointInvGrid, 'sectionsAt', function(grid, ui)
        local screen = ViewpointInvScreen
        if not screen or ui ~= screen.instance or not screen.isUp() or grid.mine or not grid.body then return end
        local top, bottom = grid.body.y, grid.body.y + grid.body.h
        for _, hit in ipairs(grid.hits or {}) do
            local target = hit.target
            if target and target.kind == 'section' and hit.y < bottom and hit.y + math.max(1, hit.h) > top then
                enqueue(target.section.container, getSpecificPlayer(0))
            end
        end
    end)
end

local function tick()
    local now = getTimestampMs()
    if now >= nextHook then install(); nextHook = now + 2000 end
    if now < nextTick then return end
    nextTick = now + 100
    for container, player in pairs(pending) do
        pending[container] = nil
        if not sent[container] or now - sent[container] >= 2000 then
            sent[container] = now
            if isClient and isClient() then
                local object = container:getParent()
                local square = object and object:getSquare()
                if square then
                    for i = 0, object:getContainerCount() - 1 do
                        if object:getContainerByIndex(i) == container then
                            sendClientCommand(player, 'SPDO', 'InspectLoot', { x = square:getX(), y = square:getY(),
                                z = square:getZ(), object = object:getObjectIndex(), container = i })
                            break
                        end
                    end
                end
            elseif SPDO_InspectNightLoot then
                SPDO_InspectNightLoot(player, container)
            end
        end
    end
end

Events.OnGameStart.Add(install)
if Events.OnTickEvenPaused then Events.OnTickEvenPaused.Add(tick)
else Events.OnTick.Add(tick) end
