dofile( "$CONTENT_DATA/Scripts/game/survival_quests.lua" )

--TODO: caching?
WindManager = class()

-- [quest] = sm.vec.new(x, y, z)
local windMap = { --TODO: add more (order matters)
    [quest_radio_location] = sm.vec3.new(-1820.5, 167.5, -7),
    [quest_find_trader] = sm.vec3.new(1536, 2048, 20),
    [quest_return_to_trader1] = sm.vec3.new(1536, 2048, 20),
    [quest_return_to_trader2] = sm.vec3.new(1536, 2048, 20),
    [quest_return_to_trader3] = sm.vec3.new(1536, 2048, 20),
    [quest_return_to_trader4] = sm.vec3.new(1536, 2048, 20),
    [quest_return_to_trader5] = sm.vec3.new(1536, 2048, 20)
}

---@param location Vec3
---@param callback function Return true if the supplied (quest) is active
---@return Vec3 windDirection
function WindManager:getWindDir(location, callback)
    local dirMiddle = location:normalize()

    -- default wind direction
    local windDirection = -dirMiddle:cross(sm.vec3.new(0,0,1))

    -- get the center with our custom callback
    local windCenter, default = self.getWindCenter(callback)

    if windCenter and not default then
        windDirection = location - windCenter
    end
    
    windDirection = windDirection:normalize()
    windDirection.z = 0

    return windDirection
end

---Get the wind center point based on active quests
---@param callback function
---@returns Vec3 boolean
function WindManager.getWindCenter(callback)
    for quest, location in pairs(windMap) do
        local completed = callback(quest)

        if not completed then
            return location, false -- break the loop
        end
    end

    return sm.vec3.new(0, 0, 0), true
end