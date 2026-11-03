if not NATIVE_LUA then return end
package.path = NATIVE_LUA .. '/shared/?.lua;' .. NATIVE_LUA .. '/server/?.lua;' .. package.path
local function check(value, message) assert(value, message); TEST_COUNT = TEST_COUNT + 1 end
local C = require 'SPDO/Config'
local S = require 'PRPGE_Settings'
local layout = require 'PRPGE_SettingsLayout'
check(S.BY_KEY.SPDO_Enabled ~= nil, 'native settings registry contains director')
check(S.Get('SPDO_Enabled') == false, 'native defaults keep director disabled')
check(S.Valid(S.BY_KEY.SPDO_xp_Value, 1.5), 'native validator accepts decimal multiplier')
check(not S.Valid(S.BY_KEY.SPDO_xp_Value, .5), 'native validator rejects invalid multiplier')
check(layout.SectionOf(S.BY_KEY.SPDO_Enabled) == 'OrchestratorAdmin', 'director settings stay out of the regular Settings pages')
check(#layout.Rows('Orchestrator', S.DEFS) == 0, 'director settings are no longer duplicated under Settings')
local saved = {}
ModData = { getOrCreate = function() return saved end }
SandboxVars = { ProjectRPGExpanded = { SPDO_HealthMin = 85 } }
check(C.Get('HealthMin') == 85, 'native sandbox fallback uses addon namespace')
local Server = require 'PRPGE_SettingsServer'
check(Server.Commit({ SPDO_Enabled = true, SPDO_xp_Value = 1.75 }), 'native server commits addon settings')
check(C.Get('Enabled') == true and C.Get('xp_Value') == 1.75, 'committed addon settings are effective')
S.values = {}; Server.Load()
check(C.Get('Enabled') == true, 'native server restores addon overrides')
local snapshot = S.Snapshot()
for _, d in ipairs(C.definitions) do check(snapshot[d.key] ~= nil, 'native MP snapshot includes ' .. d.key) end
