local Night = require 'SPDO/Night'
local Text = require 'SPDO/Locale'

local eventIconPath = 'media/ui/SurvivorPDAOrchestrator_NightEvent.png'
local nightMessages = {
    [1] = { key = 'NightAlert1', color = { 137, 232, 148 } },
    [2] = { key = 'NightAlert2', color = { 255, 210, 64 } },
    [3] = { key = 'NightAlert3', color = { 255, 140, 64 } },
    [4] = { key = 'NightAlert4', color = { 255, 80, 80 } },
}
local dawnMessage = 'DawnAlert'
local lastNightCycle
local nightWasActive = false
local nightIntroAt

local function showNotice(player, text, color)
    if not player then return end
    pcall(function() player:setHaloNote(text, color[1], color[2], color[3], 256) end)
end

local function updateNightNotice(player)
    if not Night.active then
        if not Night.enabled then
            nightWasActive = false
            lastNightCycle = Night.nightCycle
        elseif Night.isNight then
            lastNightCycle = Night.nightCycle
        elseif nightWasActive then
            showNotice(player, Text.Text(dawnMessage), { 175, 215, 255 })
            nightWasActive = false
        end
        return
    end
    if Night.isNight then
        if not Night.levelReady then return end
        if not nightWasActive or lastNightCycle ~= Night.nightCycle then
            local notice = nightMessages[tonumber(Night.level) or 1] or nightMessages[1]
            showNotice(player, Text.Text(notice.key), notice.color)
            nightIntroAt = getTimestampMs and getTimestampMs() or 0
            pcall(function() require('PRPGE_PDA').Sound('XPEvent') end)
            nightWasActive = true
            lastNightCycle = Night.nightCycle
        end
    elseif nightWasActive then
        showNotice(player, Text.Text(dawnMessage), { 175, 215, 255 })
        nightWasActive = false
    end
end

local function installEventTag()
    local ok, Boost = pcall(require, 'PRPGE_XPBoostClient')
    if not ok or type(Boost.Rows) ~= 'function' or Boost._spdoNightEvent then return end
    local rows = Boost.Rows
    Boost.Rows = function()
        local result = {}
        for _, row in ipairs(rows()) do result[#result + 1] = row end
        if Night.active then
            local levels = Night.levels or {}
            local level = tonumber(Night.level) or 1
            local selected = levels[level] or {}
            local loot = tonumber(selected.lootBonusPercent) or 0
            local sprinters = tonumber(selected.sprinterPercentage) or 0
            local colors = {
                { 0.54, 0.91, 0.58 }, { 1, 0.82, 0.25 }, { 1, 0.55, 0.25 }, { 1, 0.31, 0.31 },
            }
            result[#result + 1] = {
                'Item_SPDONightEvent', '+' .. loot .. '%', sprinters .. '% sprinters', colors[level] or colors[1],
                Text.Text('NightEventStarted'),
                string.format(Text.Text('NightEventDescription'), loot .. '%', sprinters .. '%'), nightIntroAt,
                Text.Text('NightEventTag'),
            }
        end
        return result
    end
    if type(Boost.ItemTex) == 'function' then
        local itemTex = Boost.ItemTex
        Boost.ItemTex = function(name)
            if name == 'Item_SPDONightEvent' and getTexture then
                local texture = getTexture(eventIconPath)
                if texture then return texture end
            end
            return itemTex(name)
        end
    end
    if type(Boost.DropsActive) == 'function' then
        local dropsActive = Boost.DropsActive
        Boost.DropsActive = function() return Night.active or dropsActive() end
    end
    Boost._spdoNightEvent = true
end

local function update()
    installEventTag()
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end
    updateNightNotice(player)
end

installEventTag()
if Events.OnTick then Events.OnTick.Add(update) end
