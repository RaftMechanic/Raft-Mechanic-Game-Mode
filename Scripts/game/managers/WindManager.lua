dofile( "$CONTENT_DATA/Scripts/game/raft_quests.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )

---@class WindManager : ScriptableObjectClass
WindManager = class()
WindManager.isSaveObject = true

local windMap = {
    { quest = "quest_radio_location", pos = sm.vec3.new(-1820.5, 167.5, 0)},
    { quest = "quest_find_trader", pos = sm.vec3.new(1536, 2048, 0)}
}

function WindManager.server_onCreate(self)
    g_windManager = self

    self.sv = {}
    self:sv_e_onQuestChanged()

    g_questManager.Sv_SubscribeEvent(QuestEvent.QuestCompleted, self.scriptableObject, "sv_e_onQuestChanged")
end

function WindManager:sv_e_onQuestChanged(params)
    self.sv.center = sm.vec3.zero()
    for _, wind in ipairs(windMap) do
        if not QuestManager.Sv_IsQuestComplete( wind.quest ) then
            self.sv.center = wind.pos
            break
        end
    end
    print("wind")
    print(self.sv.center)
    self.network:setClientData(self.sv)
end

function WindManager.client_onCreate(self)
    self.cl = {}

    if not sm.isHost then
        g_windManager = self
    end
end

function WindManager.client_onClientDataUpdate( self, data )
	self.cl.center = data.center
end

---GLOBAL functions

---@param location Vec3
---@return Vec3 windDirection
function getWindDir(location)

    -- get the center with our custom callback
    local windCenter = getWindCenter()
    if windCenter then --i.e. we have a quest
        local windDirection = location - windCenter
        windDirection.z = 0

        return windDirection:normalize()
    else-- i.e. there are no quests, so CIRCLES around the map
        local up = sm.vec3.new(0, 0, 1)
        local dirMiddle = location:normalize()
        local windDirection = -dirMiddle:cross(up)
        windDirection.z = 0

        return windDirection:normalize()
    end
end

---Get the wind center point cached
---@return Vec3
function getWindCenter()
    if sm.isServerMode() then
        return g_windManager.sv.center
    end

    return g_windManager.cl.center
end