local Lang = require 'PRPGE_PDALang'
local L = {}
local cache = {}
local original = getText

local function read(code)
    if cache[code] ~= nil then return cache[code] end
    local ok, result = pcall(function()
        local reader = getModFileReader('SurvivorPDAOrchestrator', 'media/lua/shared/Translate/' .. code .. '/UI.json', false)
        if not reader then return {} end
        local lines = {}
        local line = reader:readLine()
        while line do lines[#lines + 1] = line; line = reader:readLine() end
        reader:close()
        return Lang.Parse(table.concat(lines, '\n'))
    end)
    cache[code] = ok and result or {}
    return cache[code]
end

function L.Code()
    local entry = Lang.LANGS and Lang.LANGS[Lang.index]
    local code = entry and entry.code
    if not code and Translator and Translator.getLanguage then
        code = tostring(Translator.getLanguage():name())
    elseif not code and getTranslator then
        local language = getTranslator():getLanguage()
        code = language and tostring(language:name())
    end
    if code == 'PTBR' or code == 'PT' then return 'PTBR' end
    return 'EN'
end

function L.Text(key)
    local full = key:sub(1,9) == 'UI_PRPGE_' and key or 'UI_PRPGE_SPDO_' .. key
    return read(L.Code())[full] or read('EN')[full] or original(full)
end

if not Lang._spdoText then
    getText = function(key, ...)
        if type(key) == 'string' and (key:sub(1,14) == 'UI_PRPGE_SPDO_'
            or key:sub(1,21) == 'UI_PRPGE_Config_SPDO_' or key:sub(1,24) == 'UI_PRPGE_ConfigTip_SPDO_') then
            return L.Text(key)
        end
        return original(key, ...)
    end
    Lang._spdoText = true
end

return L
