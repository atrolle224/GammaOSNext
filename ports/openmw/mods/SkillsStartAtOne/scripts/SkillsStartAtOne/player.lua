-- Skills Start At One (RG477M), for OpenMW 0.49 and newer.
--
-- A new character's skills are all set to one level (1 by default) the moment character
-- creation ends: when you walk out of the Census and Excise Office with your class and
-- birthsign. Characters that were past character creation before the mod was added keep
-- their skills, unless you use "Set this character's skills now" in
-- Options > Scripts > Skills Start At One.
--
-- Leveling mods (Natural Character Growth, Skill Evolution) set up their own state when
-- character creation ends, so the level is held for a few seconds to have the last word.

local async = require('openmw.async')
local core = require('openmw.core')
local I = require('openmw.interfaces')
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local ui = require('openmw.ui')

local GROUP = 'SettingsSkillsStartAtOne'
local HOLD_SECONDS = 5
local CENSUS_OFFICE = 'seyda neen, census and excise office'

I.Settings.registerPage {
    key = 'SkillsStartAtOne',
    l10n = 'SkillsStartAtOne',
    name = 'Skills Start At One',
    description = 'pageDescription',
}
I.Settings.registerGroup {
    key = GROUP,
    page = 'SkillsStartAtOne',
    l10n = 'SkillsStartAtOne',
    name = 'Skills Start At One',
    permanentStorage = true,
    settings = {
        {
            key = 'level',
            renderer = 'number',
            name = 'levelName',
            description = 'levelDescription',
            default = 1,
            argument = { integer = true, min = 0, max = 100 },
        },
        {
            key = 'applyNow',
            renderer = 'checkbox',
            name = 'applyNowName',
            description = 'applyNowDescription',
            default = false,
        },
    },
}
local settings = storage.playerSection(GROUP)

-- 'waiting': in character creation; 'done': this character has had its skills set, or was
-- already past character creation when the mod arrived
local phase = nil
local holdUntil = 0
local lastCell = nil

local function setSkills()
    local level = settings:get('level') or 1
    for _, skill in pairs(core.stats.Skill.records) do
        local stat = types.NPC.stats.skills[skill.id](self)
        if stat.base ~= level then
            stat.base = level
        end
        stat.progress = 0
    end
end

local function start(message)
    setSkills()
    phase = 'done'
    holdUntil = core.getRealTime() + HOLD_SECONDS
    ui.showMessage(message:format(settings:get('level') or 1))
end

settings:subscribe(async:callback(function(_, key)
    if key == 'applyNow' and settings:get('applyNow') then
        settings:set('applyNow', false)
        start('Every skill set to %d.')
    end
end))

local function firstLook()
    phase = types.Player.isCharGenFinished(self) and 'done' or 'waiting'
end

return {
    engineHandlers = {
        onInit = firstLook,
        onUpdate = function()
            if phase == nil then
                firstLook()
            end
            local cell = self.cell and self.cell.name:lower() or nil
            if phase == 'waiting' then
                local leftOffice = lastCell == CENSUS_OFFICE and cell ~= CENSUS_OFFICE
                if types.Player.isCharGenFinished(self) or leftOffice then
                    start('Every skill starts at %d.')
                end
            elseif core.getRealTime() < holdUntil then
                setSkills()
            end
            lastCell = cell
        end,
        onSave = function()
            return { phase = phase }
        end,
        onLoad = function(data)
            phase = data and data.phase or nil
        end,
    },
}
