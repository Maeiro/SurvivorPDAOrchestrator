require 'support'
local callbacks, now, commands = {}, 0, {}
Events = setmetatable({}, { __index = function(t, key)
    local event = { Add = function(f) callbacks[key] = f end }; rawset(t, key, event); return event
end })
getTimestampMs = function() return now end
isClient = function() return true end
sendClientCommand = function(p, module, command, args) commands[#commands + 1] = args end
local player = {}
getSpecificPlayer = function() return player end
local square = { getX = function() return 10 end, getY = function() return 20 end, getZ = function() return 0 end }
local object = { getObjectIndex = function() return 0 end, getSquare = function() return square end,
    getContainerCount = function() return 1 end }
local c = { getParent = function() return object end, getContainingItem = function() end, getCharacter = function() end }
object.getContainerByIndex = function() return c end
local pane = { player = 0, inventory = c }
local visible, collapsed = false, false
local page = { inventoryPane = pane, getIsVisible = function() return visible end }
getPlayerLoot = function() return page end
ISInventoryPane = { render = function() end }
ErgUIPanel = { renderSideView = function() end }
ViewpointInvGrid = { sectionsAt = function() return 88 end }
local ui = {}
local viewpointUp = false
ViewpointInvScreen = { instance = ui, isUp = function() return viewpointUp end }
require 'SPDO_NightLootClient'
callbacks.OnGameStart()
local function flush() now = now + 2100; (callbacks.OnTickEvenPaused or callbacks.OnTick)() end
ISInventoryPane.render(pane); flush()
equal(#commands, 0, 'hidden vanilla pane does not inspect')
visible, page.isCollapsed = true, true
ISInventoryPane.render(pane); flush()
equal(#commands, 0, 'collapsed vanilla pane does not inspect')
page.isCollapsed = false
ISInventoryPane.render(pane)
equal(#commands, 0, 'render only queues; it does not mutate loot')
flush()
equal(#commands, 1, 'visible vanilla contents inspect selected container')
equal(commands[1].container, 0, 'stable container index sent')
local grid = { mine = false, body = { y = 100, h = 100 }, hits = {
    { y = 250, h = 40, target = { kind = 'section', section = { container = c } } },
    { y = 110, h = 20, target = { kind = 'header', section = { container = c } } },
} }
viewpointUp = true
equal(ViewpointInvGrid.sectionsAt(grid, ui), 88, 'Viewpoint return value preserved')
flush()
equal(#commands, 1, 'offscreen contents and folded header do not inspect')
grid.hits[1].y = 150
ViewpointInvGrid.sectionsAt(grid, ui); flush()
equal(#commands, 2, 'visible Viewpoint contents inspect')
local panel = { player = 0, worldContainers = { { inventory = c } }, selectedWorldIdx = 1 }
ErgUIPanel.renderSideView(panel, 'player', { zoneH = 100 }); flush()
equal(#commands, 2, 'Ergonomic personal inventory does not inspect world')
ErgUIPanel.renderSideView(panel, 'world', { zoneH = 100 }); flush()
equal(#commands, 3, 'Ergonomic selected world contents inspect')
local original = ISInventoryPane.render
callbacks.OnGameStart()
equal(ISInventoryPane.render, original, 'hooks do not stack')
ErgonomicUI = { panel = { hideVanillaInv = true } }
viewpointUp = false
ISInventoryPane.render(pane); flush()
equal(#commands, 3, 'suppressed vanilla renderer does not consume eligibility')
panel._panelAlphaNow = 0
ErgUIPanel.renderSideView(panel, 'world', { zoneH = 100 }); flush()
equal(#commands, 3, 'invisible Ergonomic panel does not consume eligibility')
