-- Skills Start At One (RG477M): when a new character finishes character creation (class,
-- birthsign and the census office), every skill is set to 1. Characters that were past
-- character creation before this mod was added are left alone.

local self = require('openmw.self')
local types = require('openmw.types')
local core = require('openmw.core')
local ui = require('openmw.ui')

-- seen during character creation: the next finished state is this character's start
local inCharGen = false
local done = false

local function setSkillsToOne()
    for _, skill in pairs(core.stats.Skill.records) do
        local stat = types.NPC.stats.skills[skill.id](self)
        stat.base = 1
        stat.progress = 0
    end
    done = true
    ui.showMessage('Every skill starts at 1.')
end

return {
    engineHandlers = {
        onUpdate = function()
            if done then
                return
            end
            if not types.Player.isCharGenFinished(self) then
                inCharGen = true
            elseif inCharGen then
                setSkillsToOne()
            end
        end,
        onSave = function()
            return { inCharGen = inCharGen, done = done }
        end,
        onLoad = function(data)
            if data then
                inCharGen = data.inCharGen
                done = data.done
            end
        end,
    },
}
