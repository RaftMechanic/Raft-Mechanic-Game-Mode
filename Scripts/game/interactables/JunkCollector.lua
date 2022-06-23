dofile "$CONTENT_DATA/Scripts/game/raft_loot.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

Collector = class()

local containerSize = 20
local containerStackSize = 256
local bodyMassThreshold = 100
local collectables = {
	blk_scrapwood,
	blk_plastic,
	obj_consumable_gas,
	obj_consumable_water,
	obj_consumable_fertilizer,
	obj_consumable_sunshake
}

local function getFirstOpenSlot( container )
    for k, v in pairs(sm.container.quantity(container)) do
        if v == 0 then
            return k - 1
        end
    end

    return nil
end

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

    self.network:sendToClients("cl_addJunk_onCreate", self.sv.data.effectData)

    self.sv.ignoreIds = {}
    self.sv.pos = sm.vec3.zero()

    self.sv.loaded = true
end

function Collector.server_onCollision( self, shape, position, selfPointVelocity, otherPointVelocity, normal )
    local openSlot = getFirstOpenSlot(self.sv.container)
    if not sm.exists(shape) or type(shape) ~= "Shape" or openSlot == nil then return end

    local shapeUUID = shape:getShapeUuid()
    local shapeId = shape:getId()
    if not isAnyOf(shapeUUID, collectables) or shape:getBody():getMass() > bodyMassThreshold or isAnyOf(shapeId, self.sv.ignoreIds) then return end

    self.sv.ignoreIds[#self.sv.ignoreIds+1] = shapeId
    local quantity = 0
    local box = shape:getBoundingBox()
    local effectData = {}
    effectData.uuid = shapeUUID
    effectData.dir = sm.vec3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)) / 100
    effectData.colour = shape:getColor()
    effectData.pos = shape:getWorldPosition()
    effectData.rot = shape:getWorldRotation()

    self.sv.data.effectData[#self.sv.data.effectData+1] = effectData

    if sm.item.isBlock( shapeUUID ) or not sm.shape.getIsStackable(shapeUUID) then
        effectData.size = box
        box = box * 4
        quantity = box.x * box.y * box.z
    else
        effectData.size = box / 2
        quantity = shape.stackedAmount
    end

    sm.container.beginTransaction()
    self.sv.container:setItem( openSlot, shapeUUID, quantity )
    sm.container.endTransaction()

    self:sv_rebuildItemTable()

    self.network:sendToClients("cl_addJunk", effectData)
    local selfPos = self.shape:getWorldPosition()
    sm.effect.playEffect("Resourcecollector - PutIn", selfPos)
    --sm.effect.playEffect("Vacuumpipe - Suction", selfPos, sm.vec3.zero(), sm.vec3.getRotation(shape:getWorldPosition() - selfPos, self.shape:getAt()))
    shape:destroyShape()
end

function Collector:server_onFixedUpdate()
    self.sv.pos = self.shape.worldPosition
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

function Collector:server_onUnload()
    self.sv.loaded = false
end

function Collector:server_onDestroy()
    if not self.sv.loaded then return end

    --probably not the best check, rip
    for k, player in pairs(sm.player.getAllPlayers()) do
        if player:getInventory():hasChanged( sm.game.getServerTick() - 1 ) then
            return
        end
    end

    local origin = sm.player.getAllPlayers()[1]
    local lootTable = {}
    for i = 1, containerSize do
        local item = self.sv.data.items[i]
        if item ~= nil and item.uuid ~= sm.uuid.getNil() then
            lootTable[#lootTable+1] = { uuid = item.uuid, chance = 1, quantity = item.quantity }
        end
    end

    raft_SpawnLoot(
        origin,
        lootTable,
        self.sv.pos
    )
end

function Collector:sv_takeAllJunk( inv )
    sm.container.beginTransaction()
    for i = 1, containerSize do
        local slot = i - 1
        local item = self.sv.container:getItem( slot )
        local itemId = item.uuid
        local itemQuant = item.quantity
        if inv:canCollect( itemId, itemQuant ) then
            sm.container.collect( inv, itemId, itemQuant )
            sm.container.spendFromSlot( self.sv.container, slot, itemId, itemQuant )
        end
    end
    sm.container.endTransaction()

    --self:sv_rebuildItemTable()
end

function Collector:sv_rebuildItemTable()
    self.sv.data.items = {}
    for i = 1, containerSize do
        self.sv.data.items[#self.sv.data.items+1] = self.sv.container:getItem( i-1 )
    end
    self.storage:save(self.sv.data)
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
    local text = junkCount == containerSize and language_tag("JunkCollector_Full") or string.format(language_tag("JunkCollector_SlotsOpen"), containerSize - junkCount)
    sm.gui.setInteractionText(o1..text..o2)
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker", true), language_tag("JunkCollector_TakeAll"))

    return true
end

function Collector.client_onInteract( self, character, state )
    if not state then return end

    local container = self.shape.interactable:getContainer( 0 )
    if container then
        self.cl.containerGui = sm.gui.createContainerGui( true )
        self.cl.containerGui:setText( "UpperName", language_tag("JunkCollector_Title") )
        self.cl.containerGui:setVisible( "ChestIcon", true )
        --self.cl.containerGui:setVisible( "TakeAll", true )
        self.cl.containerGui:setContainer( "UpperGrid", container );
        self.cl.containerGui:setText( "LowerName", "#{INVENTORY_TITLE}" )
        self.cl.containerGui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
        self.cl.containerGui:open()
    end
end

function Collector:client_onTinker( character, state )
    if not state then return end

    if getRealLength(self.cl.junk) == 0 then
        sm.gui.displayAlertText(language_tag("JunkCollector_TakeAll_Empty"), 2.5)
        return
    end

    sm.audio.play("Sledgehammer - Swing")
    self.network:sendToServer("sv_takeAllJunk", sm.localPlayer.getInventory())
end

function Collector:cl_addJunk_onCreate( data )
    for v, k in pairs(data) do
        self:cl_addJunk(k)
    end
end

function Collector:cl_addJunk( data )
    local junk = {
        effect = sm.effect.createEffect("ShapeRenderable"),
        uuid = data.uuid,
        colour = data.colour,
        size = data.size,
        pos = data.pos,
        rot = data.rot,
        dir = sm.vec3.getRotation(sm.vec3.new(0,0,1), data.dir ),
        progress = 0
    }

    junk.effect:setParameter("uuid", data.uuid)
    junk.effect:setParameter("color", data.colour)
    junk.effect:setScale(data.size)
    junk.effect:setPosition(data.pos)
    junk.effect:setRotation(data.rot)

    junk.effect:start()
    self.cl.junk[#self.cl.junk+1] = junk
end

function Collector:cl_removeJunk( index )
    if self.cl.junk[index] ~= nil then
        self.cl.junk[index].effect:stop()
        self.cl.junk[index] = nil
    end
end

function Collector:client_onUpdate( dt )
    for v, k in pairs(self.cl.junk) do
        if not k.attached then
            k.progress = k.progress + dt
            local windup = 0.4
			local progress = math.min( k.progress / 0.3, 1.0 )
			local windupProgress = ( ( progress - windup )/( 1 - windup ) )

            k.effect:setPosition( sm.vec3.lerp(k.pos, self.shape:getWorldPosition(), windupProgress))
            k.effect:setRotation( sm.quat.slerp(k.rot, k.dir, windupProgress) )

            --replace with attached effect if the pull animation is done
            if windupProgress >= 1 then
                k.attached = true
                k.effect:stopImmediate()
                k.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
                k.effect:setParameter("uuid", k.uuid)
                k.effect:setParameter("color", k.colour)
                k.effect:setScale(k.size)
                k.effect:setOffsetRotation( k.dir )
                k.effect:start()
            end
        end
    end
end