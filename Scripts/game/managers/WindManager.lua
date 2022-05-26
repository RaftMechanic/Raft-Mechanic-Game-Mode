dofile( "$CONTENT_DATA/Scripts/game/survival_quests.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua" )

---@class WindManager : ScriptableObjectClass
WindManager = class()
WindManager.isSaveObject = true

-- [quest] = sm.vec.new(x, y, z)
local windMap = { --TODO: add more (order matters) and use callbacks
    { quest = quest_radio_location, location = sm.vec3.new(-1820.5, 167.5, 0)},
    { quest = quest_find_trader, location = sm.vec3.new(1536, 2048, 0)},
    { quest = quest_return_to_trader1, location = sm.vec3.new(1536, 2048, 0)},
    { quest = quest_return_to_trader2, location = sm.vec3.new(1536, 2048, 0)},
    { quest = quest_return_to_trader3, location = sm.vec3.new(1536, 2048, 0)},
    { quest = quest_return_to_trader4, location = sm.vec3.new(1536, 2048, 0)},
    { quest = quest_return_to_trader5, location = sm.vec3.new(1536, 2048, 0)}
}

local defaultWindMap = {
    sm.vec3.new(-4096, -3072, 0),
    sm.vec3.new(-4096, 3072, 0),
    sm.vec3.new(4096, -3072, 0),
    sm.vec3.new(4096, 3072, 0)
}

function WindManager.server_onCreate(self)
    self.sv = self.storage:load() 
        
    if self.sv == nil then
        self.sv = {}
        self.sv.defaultCenter = self:sv_e_randomizeWind(false)
        self.sv.cachedWind = self:sv_caculateWindCenter()

        self.storage:save(self.sv)
    end 

    self.network:setClientData(self.sv)
    
    g_questManager.sv_subscribeEvent(g_questManager, "event.generic.quest_activated", self, "sv_e_onQuestChanged")
    g_questManager.sv_subscribeEvent(g_questManager, "event.generic.quest_completed", self, "sv_e_onQuestChanged")
    g_questManager.sv_subscribeEvent(g_questManager, "event.generic.quest_abandoned", self, "sv_e_onQuestChanged")

    g_windManager = self
end

function WindManager:sv_e_onQuestChanged(params)
    self.sv.cachedWind = self:sv_caculateWindCenter()

    self.storage:save(self.sv)
end

function WindManager.client_onCreate(self)
    self.cl = {}
    self.cl.cachedWind = sm.vec3.new(0,0,0)
    self.cl.defaultCenter = sm.vec3.new(0,0,0)

    if not sm.isHost then
        g_windManager = self
    end
end

function WindManager.client_onClientDataUpdate( self, data )
	self.cl = data
end

---Get the wind center point based on active quests
---@return Vec3
function WindManager:sv_caculateWindCenter()
    for _, data in ipairs(windMap) do
        local completed = g_questManager.Sv_IsQuestComplete(data.quest)

        if not completed then
            return data.location -- break the loop
        end
    end

    return nil
end

---Set default wind
function WindManager:sv_e_randomizeWind(set)
    local random = randomStackAmount(1, 2, 4)
    local windCenter = defaultWindMap[random]

    if set then
        self.sv.defaultCenter = windCenter
        self.storage:save(self.sv)
    end

    return windCenter
end

---GLOBAL functions

---@param location Vec3
---@return Vec3 windDirection
function getWindDir(location)

    -- get the center with our custom callback
    local windCenter = getWindCenter()

    local windDirection = location - windCenter
    
    windDirection = windDirection:normalize()
    windDirection.z = 0

    return windDirection
end

---Get the wind center point cached
---@return Vec3
function getWindCenter()
    if sm.isServerMode() then
        return g_windManager.sv.cachedWind or g_windManager.sv.defaultCenter
    end
    return g_windManager.cl.cachedWind or g_windManager.cl.defaultCenter
end