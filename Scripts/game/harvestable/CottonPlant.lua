-- CottonPlant.lua --
dofile( "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

CottonPlant = class( nil )

function CottonPlant.client_onInteract( self, state )
	self.network:sendToServer( "sv_n_harvest" )
end

function CottonPlant.client_canInteract( self )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Attack", true ), "#{INTERACTION_PICK_UP}" )
	return true
end

function CottonPlant.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if not self.harvested and sm.exists( self.harvestable ) then
		sm.effect.playEffect( "Cotton - Picked", self.harvestable.worldPosition )

		if SurvivalGame then
			local harvest = {
				lootUid = obj_resource_cotton,
				lootQuantity = 1
			}
			local pos = self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.5 )
			sm.projectile.harvestableCustomProjectileAttack( harvest, projectile_loot, 0, pos, sm.noise.gunSpread( sm.vec3.new( 0, 0, 1 ), 20 ) * 5, self.harvestable, 0 )
		

			--RAFT
			harvest = {
				lootUid = obj_seed_cotton,
				lootQuantity = 1
			}
			sm.projectile.harvestableCustomProjectileAttack( harvest, projectile_loot, 0, pos, sm.noise.gunSpread( sm.vec3.new( 0, 0, 1 ), 20 ) * 5, self.harvestable, 0 )



		end
		sm.harvestable.createHarvestable( hvs_farmables_growing_cottonplant, self.harvestable.worldPosition, self.harvestable.worldRotation )
		sm.harvestable.destroy( self.harvestable )
		self.harvested = true
	end
end

function CottonPlant.server_canErase( self ) return true end
function CottonPlant.client_canErase( self ) return true end

function CottonPlant.server_onRemoved( self, player )
	self:sv_n_harvest( nil, player )
end

function CottonPlant.client_onCreate( self )
	self.cl = {}
	self.cl.cottonfluff = sm.effect.createEffect( "Cotton - Fluff" )
	self.cl.cottonfluff:setPosition( self.harvestable.worldPosition )
	self.cl.cottonfluff:setRotation( self.harvestable.worldRotation )
	self.cl.cottonfluff:start()
end

function CottonPlant.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end

function CottonPlant.sv_n_harvest( self, params, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		if SurvivalGame then
			local container = player:getInventory()
			if sm.container.beginTransaction() then
				sm.container.collect( container, obj_resource_cotton, 1 )

				--RAFT
				sm.container.collect( container, obj_seed_cotton, 1 )
				

				if sm.container.endTransaction() then
					sm.event.sendToPlayer( player, "sv_e_onLoot", { uuid = obj_resource_cotton, pos = self.harvestable.worldPosition } )
					sm.effect.playEffect( "Cotton - Picked", self.harvestable.worldPosition )
					sm.harvestable.createHarvestable( hvs_farmables_growing_cottonplant, self.harvestable.worldPosition, self.harvestable.worldRotation )
					sm.harvestable.destroy( self.harvestable )
					self.harvested = true
				else
					self.network:sendToClient( player, "cl_n_onInventoryFull" )
				end
			end
		else
			sm.effect.playEffect( "Cotton - Picked", self.harvestable.worldPosition )
			sm.harvestable.createHarvestable( hvs_farmables_growing_cottonplant, self.harvestable.worldPosition, self.harvestable.worldRotation )
			sm.harvestable.destroy( self.harvestable )
			self.harvested = true
		end
	end
end

function CottonPlant.client_onDestroy( self )
	self.cl.cottonfluff:stop()
	self.cl.cottonfluff:destroy()
end

--RAFT
dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )

function CottonPlant:client_onFixedUpdate(dt)
	if self.harvestable then
		--WHAT IN THE ACTUAL CURSED FUCK IS HAPPENING HERE? JUST DO NOT TOUCH THIS CODE. IT IS CURSED AS FUCK
		if QuestManager.cl_getQuestProgressString(g_questManager, "quest_radio_location") == language_tag("Quest_RadioSignal_Cotton") then
			if not self.questMarkerGui then
				create_quest_marker(self)
			else
				self.questMarkerGui:setWorldPosition(self.harvestable.worldPosition + sm.vec3.new(0,0,1.25) )
			end
		elseif self.questMarkerGui then
			destroy_quest_marker(self)
		end
	end
end

function create_quest_marker(self, image)
	self.questMarkerGui = sm.gui.createWorldIconGui( 60, 60, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
	self.questMarkerGui:setImage( "Icon", image or "icon_questmarker.png" )
	self.questMarkerGui:setRequireLineOfSight( false )
	self.questMarkerGui:setMaxRenderDistance( 10000 )
	if self.harvestable then
		self.questMarkerGui:setWorldPosition(self.harvestable.worldPosition + sm.vec3.new(0,0,1.25))
	end
	self.questMarkerGui:open()
end

function destroy_quest_marker(self)
	self.questMarkerGui:close()
	self.questMarkerGui = nil
end