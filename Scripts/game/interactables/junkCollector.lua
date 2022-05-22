dofile "$CONTENT_DATA/Scripts/game/raft_loot.lua"

Collector = class()

local containerSize = 20
local containerStackSize = 256
local collectorSize = sm.vec3.new(4,4,4) / 4
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
            items = {},
            effectData = {}
        }
    end

    self.sv.container = self.interactable:getContainer( 0 )
    if self.sv.container == nil then
        self.sv.container = self.interactable:addContainer( 0, containerSize, containerStackSize )
    end

    self.sv.container.allowSpend = true
    self.sv.container.allowCollect = false

    self.sv.trigger = sm.areaTrigger.createAttachedBox( self.interactable, collectorSize, -sm.vec3.new(0,0,3)/4, sm.quat.identity(), sm.areaTrigger.filter.dynamicBody )
    self.sv.trigger:bindOnEnter("sv_checkTriggerContents")

    self.network:sendToClients("cl_addJunk_onCreate", self.sv.data.effectData)
end

function Collector:sv_checkTriggerContents( trigger, results )
    local couldCollect = false
    for i = 1, containerSize do
        if self.sv.container:getItem(i-1).uuid == sm.uuid.getNil() then
            couldCollect = true
            break
        end
    end
    if not couldCollect then return end

    for v, body in pairs(results) do
        if sm.exists(body) then
            for j, shape in pairs(body:getShapes()) do
                local shapeUUID = shape:getShapeUuid()
                if isAnyOf(shapeUUID, collectables) and body:getMass() < bodyMassThreshold then
                    local quantity = 0
                    local effectData = {}
                    local box = shape:getBoundingBox()
                    effectData.uuid = shapeUUID
                    effectData.dir = sm.vec3.new(math.random(-100, 100) / 100, math.random(-100, 100) / 100, math.random(-100, 100) / 100)
                    effectData.colour = shape:getColor()

                    self.sv.data.effectData[#self.sv.data.effectData+1] = effectData

                    if sm.item.isBlock( shapeUUID ) then
                        effectData.size = box

                        box = box * 4
                        quantity = box.x * box.y * box.z
                    else
                        --bruh sunshake
                        if sm.shape.getIsStackable(shapeUUID) then
                            effectData.size = box / 2
                            quantity = shape.stackedAmount
                        else
                            effectData.size = box
                            box = box * 4
                            quantity = box.x * box.y * box.z
                        end
                    end

                    sm.container.beginTransaction()
                    local index = 0
                    for i = 1, containerSize do
                        if self.sv.container:getItem(i-1).uuid == sm.uuid.getNil() then
                            index = i - 1
                            break
                        end
                    end

                    self.sv.container:setItem( index, shapeUUID, quantity )
                    sm.container.endTransaction()

                    self.sv.data.items = {}
                    for i = 1, containerSize do
                        self.sv.data.items[#self.sv.data.items+1] = self.sv.container:getItem( i-1 )
                    end
                    self.storage:save(self.sv.data)

                    self.network:sendToClients("cl_addJunk", effectData)
                    local selfPos = self.shape:getWorldPosition()
                    sm.effect.playEffect("Resourcecollector - PutIn", selfPos)
                    --sm.effect.playEffect("Vacuumpipe - Suction", selfPos, sm.vec3.zero(), sm.vec3.getRotation(shape:getWorldPosition() - selfPos, self.shape:getAt()))
                    shape:destroyShape()
                end
            end
        end
    end
end

function Collector:server_onFixedUpdate()
    if self.sv.container:hasChanged( sm.game.getServerTick() - 1 ) then
        for i = 1, containerSize do
            local item = self.sv.container:getItem( i-1 )
            if self.sv.data.items[i] ~= nil and self.sv.data.items[i].uuid ~= item.uuid then
                self.network:sendToClients("cl_removeJunk", i)
                self.sv.data.items[i] = nil
                self.sv.data.effectData[i] = nil
                self.storage:save(self.sv.data)
            end
        end
    end
end

function Collector:server_onDestroy()
    --[[for v, item in pairs(self.sv.data.items) do
        if item.uuid ~= sm.uuid.getNil() then
            raft_SpawnLoot( self.shape, { { uuid = item.uuid, quantity = item.quantity } } )
        end
    end]]
end


function Collector:client_onCreate()
    self.cl = {}
    self.cl.junk = {}
    self.cl.containerGui = nil
end

local function getRealLength( table )
    local length = 0
    for v, k in pairs(table) do
        length = length + 1
    end

    return length
end

function Collector:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    local junkCount = getRealLength(self.cl.junk)
    local text = junkCount == containerSize and language_tag("JunkCollector_Full") or string.format(language_tag("JunkCollector_SlotsOpen"), tostring(containerSize - junkCount))
    sm.gui.setInteractionText(o1..text..o2)

    return true
end

function Collector.client_onInteract( self, character, state )
	if state == true then
		local container = self.shape.interactable:getContainer( 0 )
		if container then
			self.cl.containerGui = sm.gui.createContainerGui( true )
			self.cl.containerGui:setText( "UpperName", "#{CHEST_TITLE_CHEST}" )
			self.cl.containerGui:setVisible( "ChestIcon", true )
            self.cl.containerGui:setVisible( "TakeAll", true )
			self.cl.containerGui:setContainer( "UpperGrid", container );
			self.cl.containerGui:setText( "LowerName", "#{INVENTORY_TITLE}" )
			self.cl.containerGui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
			self.cl.containerGui:open()
		end
	end
end

function Collector:cl_addJunk_onCreate( data )
    for v, k in pairs(data) do
        self:cl_addJunk(k)
    end
end

function Collector:cl_addJunk( data )
    local junk = { effect = sm.effect.createEffect("ShapeRenderable", self.interactable), dir = data.dir }
    junk.effect:setParameter("uuid", data.uuid)
    junk.effect:setParameter("color", data.colour)
    junk.effect:setScale(data.size)

    junk.effect:start()
    self.cl.junk[#self.cl.junk+1] = junk
end

function Collector:cl_removeJunk( index )
    if self.cl.junk[index] ~= nil then
        self.cl.junk[index].effect:stop()
        self.cl.junk[index] = nil
    end
end

function Collector:client_onUpdate()
    for v, k in pairs(self.cl.junk) do
        k.effect:setOffsetRotation( sm.vec3.getRotation(sm.vec3.new(0,0,1), k.dir) )
    end
end