Collector = class()

local containerSize = 5
local containerStackSize = 256
local collectorSize = sm.vec3.new(4,4,1) / 4
local bodyMassThreshold = 100

local collectables = {
	blk_scrapwood,
	blk_plastic,
	obj_consumable_gas,
	obj_consumable_water,
	obj_consumable_fertilizer,
	obj_consumable_sunshake
}

function Collector:server_onCreate()
    self.sv = {}
    self.sv.data = self.storage:load()
    if self.sv.data == nil then
        self.sv.data = {

        }
    end

    self.sv.container = self.interactable:getContainer( 0 )
    if self.sv.container == nil then
        self.sv.container = self.interactable:addContainer( 0, containerSize, containerStackSize )
    end

    self.sv.trigger = sm.areaTrigger.createAttachedBox( self.interactable, collectorSize, sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.dynamicBody )
end

function Collector:server_onFixedUpdate()
    if not self.sv.trigger then return end

    for v, body in pairs(self.sv.trigger:getContents()) do
        local shape = body:getShape()
        local shapeUUID = shape:getShapeUuid()
        if isAnyOf(shapeUUID, collectables) and body:getMass() < bodyMassThreshold then
            local effectData = {}
            effectData.uuid = shapeUUID
            if sm.item.isBlock( shapeUUID ) then
                effectData.size = shape:getBoundingBox()
            end
        end
    end
end


function Collector:client_onCreate()
    self.cl = {}
    self.cl.effects = {} --oh no
end