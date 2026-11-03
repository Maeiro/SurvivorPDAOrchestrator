local support = require 'support'
local lang = { index = 1, LANGS = { {}, { code = 'EN' }, { code = 'PTBR' }, { code = 'DE' } }, Parse = JSON_DECODE }
package.loaded.PRPGE_PDALang = lang
local original = function(key) return key end
getText = original
local gameLanguage = 'EN'
getTranslator = function() return { getLanguage = function() return { name = function() return gameLanguage end } end } end
Translator = { getLanguage = function() return { name = function() return gameLanguage end } end }
getModFileReader = function(id, path)
    equal(id, 'SurvivorPDAOrchestrator')
    local file = io.open(MOD_ROOT .. '/42/' .. path, 'r')
    if not file then return nil end
    return { readLine = function() return file:read('*l') end, close = function() file:close() end }
end
local L = require 'SPDO/Locale'
equal(L.Text('Title'), 'ORCHESTRATOR')
equal(getText('UI_PRPGE_Config_SPDO_Enabled'), 'Enable Orchestrator')
equal(getText('UI_PRPGE_SPDO_Rare'), 'Rare (60–120 min)')
equal(getText('UI_PRPGE_Unrelated'), 'UI_PRPGE_Unrelated', 'other translations preserved')
lang.index = 3
equal(L.Text('Title'), 'ORQUESTRADOR', 'PDA language wins over game language')
equal(getText('UI_PRPGE_Config_SPDO_Enabled'), 'Ativar Orquestrador')
check(not getText('UI_PRPGE_ConfigTip_SPDO_Enabled'):find('UI_PRPGE_'), 'tooltips localized')
lang.index = 4; equal(L.Text('Title'), 'ORCHESTRATOR', 'unsupported language falls back to English')
lang.index = 1; gameLanguage = 'PTBR'; equal(L.Text('Title'), 'ORQUESTRADOR', 'PDA default follows game language')

local Panel = { SECTIONS = { 'dashboard' }, SEC = {}, DRAW = { settings = function() return 'native' end } }
Panel.key = function(self, r, label, fn, style, icon, tip, key) self.keys[key] = { fn = fn, label = label } end
Panel.settingRow = function(self, d) self.labels[#self.labels + 1] = getText('UI_PRPGE_Config_' .. d.key) end
Panel.list = function(self, id, r, n, rowHeight, draw) for i = 1, n do draw(i, {x=0,y=0,w=1000,h=32}) end end
Panel.text = function(self, text) self.labels[#self.labels + 1] = text end
package.loaded.PRPGE_AdminConsole = Panel
package.loaded.PRPGE_Skin = { TEXT = {} }
package.loaded.PRPGE_SettingsPanel = { GROUPS = {} }
local command
Events = { OnServerCommand = { Add = function(fn) command = fn end } }
UIFont = { Small = 1 }
local wall, requests, lastCommand = 0, 0, nil
getTimestampMs = function() return wall end
isClient = function() return false end
SPDO_Request = function(_, name) requests = requests + 1; lastCommand = name end
require 'SPDO_Client'
local panel = setmetatable({ sec = 'orchestrator', scroll = {}, keys = {}, labels = {}, player = {} }, { __index = Panel })
local r = { x=0, y=0, w=1000, h=600 }
equal(Panel.SECTIONS[2], 'orchestrator', 'Orchestrator is a top-level admin section')
equal(Panel.SEC.orchestrator[1], 'SPDO_Title')
Panel.DRAW.orchestrator(panel, r)
equal(requests, 1); equal(panel.keys.spdoTab1.label, 'Diagnóstico')
Panel.DRAW.orchestrator(panel, r); equal(requests, 1, 'draw cannot spam server requests')
panel.keys.spdoForceDecision.fn(); equal(lastCommand, 'ForceDecision', 'manual decision uses its dedicated command')
panel.keys.spdoTab2.fn(); Panel.DRAW.orchestrator(panel, r)
check(#panel.labels > 1, 'configuration appears')
for _, label in ipairs(panel.labels) do check(not label:find('UI_PRPGE_'), 'missing translation: ' .. label) end
panel.keys.spdoTab3.fn(); Panel.DRAW.orchestrator(panel, r)
panel.keys.spdoTab4.fn(); Panel.DRAW.orchestrator(panel, r)
for _, label in ipairs(panel.labels) do check(not label:find('UI_PRPGE_'), 'missing advanced translation: ' .. label) end
command('SPDO', 'Snapshot', { reason='Waiting', history={{at=0,reason='OpportunityStarted',event='xp'}}, blocked={{player='Alice',reason='LowHealth'}} })
panel.keys.spdoTab1.fn(); wall = 6000; Panel.DRAW.orchestrator(panel, r)
equal(requests, 3)
equal(Panel.DRAW.settings(panel, r), 'native', 'native Settings page preserved')
lang.index = 2; Panel.DRAW.orchestrator(panel, r)
equal(L.Text('Title'), 'ORCHESTRATOR', 'live PDA language switch')
