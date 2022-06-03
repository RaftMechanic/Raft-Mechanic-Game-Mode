dofile( "$SURVIVAL_DATA/Scripts/game/survival_items.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_items.lua" )

ConsumableContainer = class( nil )
ConsumableContainer.maxChildCount = 255

local ContainerSize = 5

function ConsumableContainer.server_onCreate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, ContainerSize, self.data.stackSize )
	end
	if self.data.filterUid then
		local filters = { sm.uuid.new( self.data.filterUid ) }
		container:setFilters( filters )
	end
end

function ConsumableContainer.client_canCarry( self )
	local container = self.shape.interactable:getContainer( 0 )
	if container and sm.exists( container ) then
		return not container:isEmpty()
	end
	return false
end

function ConsumableContainer.client_onInteract( self, character, state )
	if state == true then
		local container = self.shape.interactable:getContainer( 0 )
		if container then
			local gui = nil

			local shapeUuid = self.shape:getShapeUuid()

			if shapeUuid == obj_container_ammo then
				gui = sm.gui.createAmmunitionContainerGui( true )

			elseif shapeUuid == obj_container_battery then
				gui = sm.gui.createBatteryContainerGui( true )

			elseif shapeUuid == obj_container_chemical then
				gui = sm.gui.createChemicalContainerGui( true )

			elseif shapeUuid == obj_container_fertilizer then
				gui = sm.gui.createFertilizerContainerGui( true )

			elseif shapeUuid == obj_container_gas then
				gui = sm.gui.createGasContainerGui( true )

			elseif shapeUuid == obj_container_seed then
				gui = sm.gui.createSeedContainerGui( true )

			elseif shapeUuid == obj_container_water then
				gui = sm.gui.createWaterContainerGui( true )
			end

			if gui == nil then
				gui = sm.gui.createContainerGui( true )
				gui:setText( "UpperName", "#{CONTAINER_TITLE_GENERIC}" )
			end

			gui:setContainer( "UpperGrid", container )
			gui:setText( "LowerName", "#{INVENTORY_TITLE}" )
			gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
			gui:open()
		end
	end
end

function ConsumableContainer.client_onUpdate( self, dt )

	local container = self.shape.interactable:getContainer( 0 )
	if container and self.data.stackSize then
		local quantities = sm.container.quantity( container )

		local quantity = 0
		for _,q in ipairs( quantities ) do
			quantity = quantity + q
		end

		local frame = ContainerSize - math.ceil( quantity / self.data.stackSize )
		self.interactable:setUvFrameIndex( frame )
	end
end

FoodContainer = class( ConsumableContainer )

local FoodUuids = {
	obj_plantables_banana,
	obj_plantables_blueberry,
	obj_plantables_orange,
	obj_plantables_pineapple,
	obj_plantables_carrot,
	obj_plantables_redbeet,
	obj_plantables_tomato,
	obj_plantables_broccoli,
	obj_plantables_potato,
	obj_consumable_sunshake,
	obj_consumable_carrotburger,
	obj_consumable_pizzaburger,
	obj_consumable_longsandwich,
	obj_consumable_milk,
	obj_resource_steak,
	obj_resource_corn,
    --RAFT
    obj_water_clean,
    obj_fish,
    obj_fishus,
    obj_fish_cooked,
    -- Allow bees to be "frozen" or put into forceful hibernation
    obj_bee_queen
    --RAFT END
}

function FoodContainer.server_onCreate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container =	self.shape:getInteractable():addContainer( 0, 20 )
	end
	container:setFilters( FoodUuids )
end

FoodContainer.client_onUpdate = nil
