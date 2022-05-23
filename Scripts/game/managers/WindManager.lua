dofile( "$CONTENT_DATA/Scripts/game/survival_quests.lua" )

WindManager = class()

-- [quest] = sm.vec.new(x, y, z)
local windMap = { --TODO: add more (order matters) and use callbacks
    [quest_radio_location] = sm.vec3.new(-1820.5, 167.5, 0),
    [quest_find_trader] = sm.vec3.new(1536, 2048, 0),
    [quest_return_to_trader1] = sm.vec3.new(1536, 2048, 0),
    [quest_return_to_trader2] = sm.vec3.new(1536, 2048, 0),
    [quest_return_to_trader3] = sm.vec3.new(1536, 2048, 0),
    [quest_return_to_trader4] = sm.vec3.new(1536, 2048, 0),
    [quest_return_to_trader5] = sm.vec3.new(1536, 2048, 0)
}

local defaultWindMap = {
    sm.vec3.new(-4096, -3072, 0),
    sm.vec3.new(-4096, 3072, 0),
    sm.vec3.new(4096, -3072, 0),
    sm.vec3.new(4096, 3072, 0)
}

---@param location Vec3
---@param callback function Return true if the supplied (quest) is active
---@return Vec3 windDirection
function WindManager:getWindDir(location, callback)

    -- get the center with our custom callback
    local windCenter = self:getWindCenter(callback)

    local windDirection = location - windCenter
    
    windDirection = windDirection:normalize()
    windDirection.z = 0

    return windDirection
end

---Get the wind center point based on active quests
---@param callback function
---@return Vec3
function WindManager:getWindCenter(callback)
    for quest, location in pairs(windMap) do
        local completed = callback(quest)

        if not completed then
            return location -- break the loop
        end
    end

    if self.defaultCenter == nil and sm.isServerMode() then
        self:sv_randomizeWind()
    end

    return self.defaultCenter or sm.vec3.new(0, 0, 0)
end

---Set default wind
function WindManager:sv_randomizeWind()
    local random = math.floor(math.random(0, 3)) + 1 -- random d4
    local windCenter = defaultWindMap[random]

    --FIXME maybe use setClientData
	sm.event.sendToGame( "sv_e_onWindUpdate", windCenter )
end

function WindManager:cl_onWindUpdate(center)
    self.defaultCenter = center
end

