-- OilGeyser.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"

OilGeyser = class( nil )

--Raft
OilGeyser.spawnJunk = -1

function OilGeyser.client_onInteract( self, state )
	self.network:sendToServer( "sv_n_harvest" )
end

function OilGeyser.client_canInteract( self )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Attack", true ), "#{INTERACTION_PICK_UP}" )
	return true
end

function OilGeyser.server_canErase( self ) return true end
function OilGeyser.client_canErase( self ) return true end

function OilGeyser.server_onRemoved( self, player )
	self:sv_n_harvest( nil, player )
end

function OilGeyser.client_onCreate( self )
	self.cl = {}
	self.cl.activeGeyser = sm.effect.createEffect( "Oilgeyser - OilgeyserLoop" )
	self.cl.activeGeyser:setPosition( self.harvestable.worldPosition )
	self.cl.activeGeyser:setRotation( self.harvestable.worldRotation )
	self.cl.activeGeyser:start()
	self.cl.activeGeyserAmbience = sm.effect.createEffect( "Oilgeyser - OilgeyserAmbience" )
	self.cl.activeGeyserAmbience:setPosition( self.harvestable.worldPosition )
	self.cl.activeGeyserAmbience:setRotation( self.harvestable.worldRotation )
	self.cl.activeGeyserAmbience:start()
end

function OilGeyser.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end

function OilGeyser.sv_n_harvest( self, params, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		if SurvivalGame then
			local container = player:getInventory()
			local quantity = randomStackAmount( 1, 2, 4 )
			if sm.container.beginTransaction() then
				sm.container.collect( container, obj_resource_crudeoil, quantity )
				if sm.container.endTransaction() then
					sm.event.sendToPlayer( player, "sv_e_onLoot", { uuid = obj_resource_crudeoil, quantity = quantity, pos = self.harvestable.worldPosition } )
					sm.effect.playEffect( "Oilgeyser - Picked", self.harvestable.worldPosition )
					sm.harvestable.createHarvestable( hvs_farmables_growing_oilgeyser, self.harvestable.worldPosition, self.harvestable.worldRotation )
					sm.harvestable.destroy( self.harvestable )
					self.harvested = true
				else
					self.network:sendToClient( player, "cl_n_onInventoryFull" )
				end
			end
		else
			sm.effect.playEffect( "Oilgeyser - Picked", self.harvestable.worldPosition )
			sm.harvestable.createHarvestable( hvs_farmables_growing_oilgeyser, self.harvestable.worldPosition, self.harvestable.worldRotation )
			sm.harvestable.destroy( self.harvestable )
			self.harvested = true
		end
	end
end

function OilGeyser.client_onDestroy( self )
	self.cl.activeGeyser:destroy()
	self.cl.activeGeyserAmbience:destroy()
end

--Raft
function OilGeyser.server_onCreate( self )
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = true
		self.storage:save( self.saved )
		self.spawnJunk = 10
	end
end

function OilGeyser.server_onFixedUpdate( self, state )
	if self.spawnJunk == 0 then
		self:server_spawnJunk()
	end
	self.spawnJunk = self.spawnJunk - 1
end

function OilGeyser.server_spawnJunk(self)
	local vec = self.harvestable:getPosition()
	vec.z = -2

	local random = math.random(1,1000)
	local junkIndex
	if random <= 10 then
		local crate = hvs_lootcrate
		if math.random(1,25) == 25 then
			crate = hvs_lootcrateepic
		end

		sm.harvestable.create( crate, vec, self.harvestable.worldRotation )
		return
	elseif random <= 100 then
		local toYaw = function( rotation )
			local spawnDirection = rotation * sm.vec3.new( 0, 1, 0 )
			return math.atan2( spawnDirection.y, spawnDirection.x ) - math.pi / 2
		end

		local dif = sm.vec3.new( -2336, -2592, 16 ) - vec
		local safeDistance = 64*4

		if math.abs(dif.x) > safeDistance or math.abs(dif.y) > safeDistance then
			sm.unit.createUnit( unit_sharkbot, vec + sm.vec3.new(0,0,2.5), toYaw( self.harvestable:getRotation() ), { tetherPoint = vec, deathTick = sm.game.getCurrentTick() + DaysInTicks( 5 ) + 400 } )
		end

		return
	elseif random <= 110 then
		junkIndex = 6
	elseif random <= 125 then
		junkIndex = 5
	elseif random <= 200 then
		junkIndex = 4
	elseif random <= 275 then
		junkIndex = 3
	elseif random <= 600 then
		junkIndex = 2
	elseif random <= 602 then
		junkIndex = 100 + math.random(1,3) --Abandoned raft
	else
		junkIndex = 1
	end

	local player = sm.player.getAllPlayers()[1]
	if player:getCharacter() == nil then
		self.spawnJunk = 10
		return
	end

	local status, error = pcall( sm.creation.importFromFile( player:getCharacter():getWorld(), "$CONTENT_DATA/LocalBlueprints/junk" .. tostring(junkIndex) .. ".blueprint", vec ) )
end
