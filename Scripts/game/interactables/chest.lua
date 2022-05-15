-- Chest.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_items.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_loot.lua"

Chest = class( nil )

local sinkStartDelay = 120
local dissolvaStartDelay = 80
local dissolveFrequency = 10
local dissolveChance = 0.9

local function addToTable(t1,t2)
    for _,v in ipairs(t2) do 
        table.insert(t1, v)
    end
end

local function getRealLength( table )
    local length = 0
    for v, k in pairs(table) do
        length = length + 1
    end

    return length
end

function Chest.server_onCreate( self )
    self.sv = {}

    self.sv.container = self.shape.interactable:getContainer( 0 )
    if self.sv.container == nil then
		self.sv.container = self.shape:getInteractable():addContainer( 0, 20, 256 )
	end

	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}

        --self.sv.saved.mass = 0
        self.sv.saved.sink = nil
        self.sv.saved.dissolve = nil
        self.sv.saved.shapesToSink = {}
        self.sv.saved.sinkStartTick = nil
        self.sv.saved.dissolveStartTick = 0

        for _, body in pairs(self.shape:getBody():getCreationBodies()) do
            body:setDestructable(false)
            body:setPaintable(false)
            body:setConnectable(false)
            body:setLiftable(false)
            body:setErasable(false)

            --self.sv.saved.mass = self.sv.saved.mass + body:getMass()
        end

        local loot = {}
        addToTable(loot, SelectLoot("loot_ruinchest", 20))
        addToTable(loot, SelectLoot("loot_ruinchest", 20))
        addToTable(loot, SelectLoot("loot_ruinchest", 20))
        addToTable(loot, SelectLoot("loot_ruinchest_startarea", 20))
        addToTable(loot, SelectLoot("loot_crate_standard", 20))
        addToTable(loot, SelectLoot("loot_crate_standard", 20))
        addToTable(loot, SelectLoot("loot_crate_epic", 20))

        if sm.container.beginTransaction() then
            if math.random(1,10) < 7 then
                sm.container.collect( self.sv.container, obj_consumable_soilbag, math.random(1,3), false )
            end
            for _, item in pairs(loot) do
                sm.container.collect( self.sv.container, item.uuid, item.quantity, false )
            end
            sm.container.endTransaction()
        end

        self.sv.container.allowSpend = true
	    self.sv.container.allowCollect = false
	end
	self.storage:save( self.sv.saved )
end

function Chest.client_onDestroy( self )
	if self.cl.containerGui then
		if sm.exists( self.cl.containerGui ) then
			self.cl.containerGui:close()
			self.cl.containerGui:destroy()
		end
	end
end

function Chest.server_onFixedUpdate( self )
    --[[for v, shape in pairs(self.sv.saved.shapesToSink) do
        sm.shape.destroyShape(shape, 0)
    end]]

    local currenTick = sm.game.getServerTick()
    if self.sv.container == nil or self.sv.saved.sinkStartTick == nil or currenTick < self.sv.saved.sinkStartTick + sinkStartDelay then return
    elseif currenTick == self.sv.saved.sinkStartTick + sinkStartDelay then self.sv.saved.sink = currenTick end

    local down = sm.vec3.new(0,0,-1)
    local force = (currenTick - self.sv.saved.sink) / 2500
    for v, shape in pairs(self.sv.saved.shapesToSink) do
        if sm.exists(shape) then
            local body = shape:getBody()
            sm.physics.applyImpulse(body, down*force*body:getMass() / 12, true)
        end
    end

    if self.shape:getBody():getCenterOfMassPosition().z < -5 and self.shape:getBody():getVelocity() < sm.vec3.new(0.001,0.01,0.001) and not self.sv.saved.dissolve then
        self.sv.saved.dissolve = currenTick
        self.sv.saved.dissolveStartTick = currenTick
        self.storage:save( self.sv.saved )

        --[[for _, shape in pairs(self.shape:getBody():getCreationShapes()) do
            sm.shape.destroyShape(shape, 0)
        end]]
    end

    if self.sv.saved.dissolve == nil or currenTick < self.sv.saved.dissolveStartTick + dissolvaStartDelay then return end

    if currenTick >= self.sv.saved.dissolve + dissolveFrequency then
        self.sv.saved.dissolve = currenTick
        for v, shape in pairs(self.sv.saved.shapesToSink) do
            local oneManStanding = getRealLength(self.sv.saved.shapesToSink) == 1
            if sm.exists(shape) then
                if shape ~= self.shape and math.random() < dissolveChance or oneManStanding then
                    if oneManStanding then
                        sm.effect.playEffect( "Part - Upgrade", self.shape:getWorldPosition(), sm.vec3.zero(), sm.vec3.getRotation( sm.vec3.new(0,1,0), sm.vec3.new(0,0,1) ) )
                    end

                    sm.shape.destroyShape(shape, 0)
                    self.sv.saved.shapesToSink[v] = nil
                    break
                end
            else
                self.sv.saved.shapesToSink[v] = nil
            end
        end
    end
end

function Chest:sv_setSink( sink )
    if self.sv.saved.sink == nil and sm.container.isEmpty( self.sv.container ) then
        --self.sv.saved.sink = sink
        self.sv.saved.sinkStartTick = sink
        self.sv.saved.shapesToSink = self.shape:getBody():getCreationShapes()
        self.storage:save( self.sv.saved )
    end
end

function Chest.client_onCreate( self )
	if self.cl == nil then
		self.cl = {}
	end
end

function Chest.client_onInteract( self, character, state )
	if state == true then
		local container = self.shape.interactable:getContainer( 0 )
		if container then
			self.cl.containerGui = sm.gui.createContainerGui( true )
			self.cl.containerGui:setText( "UpperName", "#{CHEST_TITLE_CHEST}" )
			self.cl.containerGui:setVisible( "ChestIcon", false )
			self.cl.containerGui:setVisible( "ChestIcon", true )
			self.cl.containerGui:setContainer( "UpperGrid", container );
			self.cl.containerGui:setText( "LowerName", "#{INVENTORY_TITLE}" )
			self.cl.containerGui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
			self.cl.containerGui:open()
		end
    else
        self.network:sendToServer("sv_setSink", sm.game.getCurrentTick())
	end
end

function Chest.client_canInteract( self )
	return true
end