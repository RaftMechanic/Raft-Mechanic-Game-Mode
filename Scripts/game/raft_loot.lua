
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )

local loot_sharkbot = {
	slots = function() return randomStackAmount( 2, 2, 2 ) end,
	selectOne = {
		{ uuid = obj_interactive_raftshark, 	chance = 1,		quantity = 1 },
		{ uuid = nil,							chance = 2 }, -- No loot from selectOne
	},
	randomLoot = {
		{ uuid = obj_consumable_component,		chance = 1,		quantity = randomStackAmountAvg2 },
		{ uuid = obj_resource_circuitboard,		chance = 2,		quantity = randomStackAmountAvg2 },
	}
}

local loot_totebot_green = {
	slots = function() return randomStackAmount( 1, 1.5, 2 ) end,
	randomLoot = {
		{ uuid = obj_resource_circuitboard,		chance = 1 },
	}
}

local loot_haybot = {
	slots = function() return randomStackAmount( 1, 1.5, 2 ) end,
	randomLoot = {
		{ uuid = obj_consumable_component,		chance = 2 },
		{ uuid = obj_resource_circuitboard,		chance = 3 },
	}
}


local loot_farmbot = {
	slots = function() return randomStackAmount( 2, 2, 3 ) end,
	randomLoot = {
		{ uuid = obj_consumable_component,		chance = 2,		quantity = randomStackAmountAvg2 },
		{ uuid = obj_resource_circuitboard,		chance = 1,		quantity = randomStackAmountAvg2 },
	}
}

local lootTables = {
	["loot_sharkbot"] = loot_sharkbot,
	["loot_farmbot"] = loot_farmbot,
	["loot_haybot"] = loot_haybot,
	["loot_totebot_green"] = loot_totebot_green
}

function raft_SelectOne( list )
	local sum = 0
	for _,v in ipairs( list ) do
		sum = sum + v.chance --NOTE: Could precalculate sum
	end

	local rand = math.random() * sum

	sum = 0
	for _,v in ipairs( list ) do
		sum = sum + v.chance

		if rand <= sum then
			local quantity = 1
			if v.quantity then
				if type( v.quantity ) == "function" then
					quantity = v.quantity()
				else
					quantity = v.quantity
				end
			end
			return {
				uuid = v.uuid,
				quantity = quantity
			}
		end
	end
	return nil
end

function raft_SelectLoot( lootTableName, slotLimit )
	local lootList = {}

	local lootTable = lootTables[lootTableName]

	local slots = lootTable.slots and lootTable.slots() or 1
	if slotLimit then
		slots = math.min( slots, slotLimit )
	end

	if slots > 0 and lootTable.selectOne then
		local loot = SelectOne( lootTable.selectOne )
		if loot and loot.uuid then
			if isAnyOf( lootTableName, { "loot_crate_epic", "loot_crate_epic_warehouse" } ) then
				loot.epic = true
			end
			lootList[#lootList + 1] = loot
		end
	end

	while #lootList < slots and lootTable.randomLoot do
		local loot = SelectOne( lootTable.randomLoot )
		assert( loot and loot.uuid )
		lootList[#lootList + 1] = loot
	end

	return lootList
end

function raft_SpawnLoot( origin, lootList, worldPosition, ringAngle )

	if worldPosition == nil then
		if type( origin ) == "Shape" then
			worldPosition = origin.worldPosition
		elseif type( origin ) == "Player" or type( origin ) == "Unit" then
			local character = origin:getCharacter()
			if character then
				worldPosition = character.worldPosition
			end
		elseif type( origin ) == "Harvestable" then
			worldPosition = origin.worldPosition
		end
	end

	ringAngle = ringAngle or math.pi / 18

	if worldPosition then
		for i = 1, #lootList do
			local dir
			local up
			if type( origin ) == "Shape" then
				dir = sm.vec3.new( 1.0, 0.0, 0.0 )
				up = sm.vec3.new( 0, 1, 0 )
			else
				dir = sm.vec3.new( 0.0, 1.0, 0.0 )
				up = sm.vec3.new( 0, 0, 1 )
			end

			local firstCircle = 6
			local secondCircle = 13
			local thirdCircle = 26

			if i < 6 then
				local divisions = ( firstCircle - ( firstCircle - math.min( #lootList, firstCircle - 1 ) ) )
				dir = dir:rotate( i * 2 * math.pi / divisions, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - ringAngle, right )
			elseif i < 13 then
				local divisions = ( secondCircle - ( secondCircle - math.min( #lootList - firstCircle + 1, secondCircle - firstCircle ) ) )
				dir = dir:rotate( i * 2 * math.pi / divisions, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - 2 * ringAngle, right )
			elseif i < 26 then
				local dvisions = ( thirdCircle - ( thirdCircle - math.min( #lootList - secondCircle + 1, thirdCircle - secondCircle ) ) )
				dir = dir:rotate( i * 2 * math.pi / dvisions, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - 4 * ringAngle, right )
			else
				-- Out of predetermined room, place randomly
				dir = dir:rotate( math.random() * 2 * math.pi, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - ringAngle - math.random() * ( 3 * ringAngle ), right )
			end

			local loot = lootList[i]
			local params = { lootUid = loot.uuid, lootQuantity = loot.quantity or 1, epic = loot.epic }
			local vel = dir * (4+math.random()*2)
			local projectileUuid = loot.epic and projectile_epicloot or projectile_loot
			if type( origin ) == "Shape" then
				sm.projectile.shapeCustomProjectileAttack( params, projectileUuid, 0, sm.vec3.new( 0, 0, 0 ), vel, origin, 0 )
			elseif type( origin ) == "Player" or type( origin ) == "Unit" then
				sm.projectile.customProjectileAttack( params, projectileUuid, 0, worldPosition, vel, origin, worldPosition, worldPosition, 0 )
			elseif type( origin ) == "Harvestable" then
				sm.projectile.harvestableCustomProjectileAttack( params, projectileUuid, 0, worldPosition, vel, origin, 0 )
			end
		end
	end
end
