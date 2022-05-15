-- Crafter.lua --

dofile "$SURVIVAL_DATA/Scripts/game/survival_items.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_survivalobjects.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/pipes.lua"

Crafter = class( nil )
Crafter.colorNormal = sm.color.new( 0x84ff32ff )
Crafter.colorHighlight = sm.color.new( 0xa7ff4fff )

--raft
dofile "$CONTENT_DATA/Scripts/game/survival_quests.lua"
local raftbots = {
	obj_scrap_field,
	obj_scrap_purifier,
	obj_scrap_tree_grower,
	obj_apiary,
	obj_scrap_workbench,
	obj_large_field,
	obj_seed_press,
	obj_grill
}

local crops = {
	obj_plantables_redbeet,
	obj_plantables_carrot,
	obj_plantables_tomato,
	obj_plantables_potato,
	obj_resource_cotton,
	obj_plantables_banana,
	obj_plantables_blueberry,
	obj_plantables_orange,
	obj_plantables_broccoli,
	obj_plantables_pineapple,
	obj_resource_flower
}

local crafters = {
	-- Workbench
	[tostring( obj_survivalobject_workbench )] = {
		needsPower = true,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "workbench", locked = false }
		},
		subTitle = "Workbench",
		createGuiFunction = sm.gui.createWorkbenchGui
	},
	-- Dispenser
	[tostring( obj_survivalobject_dispenserbot )] = {
		needsPower = true,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "dispenser", locked = false }
		},
		subTitle = "Dispenser",
		createGuiFunction = sm.gui.createMechanicStationGui
	},
	-- Cookbot
	[tostring( obj_craftbot_cookbot )] = {
		needsPower = false,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "cookbot", locked = false }
		},
		subTitle = "Cookbot",
		createGuiFunction = sm.gui.createCookBotGui
	},
	-- ScrapFarm
	[tostring( obj_scrap_field )] = {
		needsPower = false,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "farm", locked = false }
		},
		subTitle = "Scrap Field",
		name = "Tiny Field",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- BigFarm
	[tostring( obj_large_field )] = {
		needsPower = false,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "bigfarm", locked = false }
		},
		subTitle = "Large Field",
		name = "Big Field",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- ScrapPurifier
	[tostring( obj_scrap_purifier )] = {
		needsPower = false,
		slots = 2,
		speed = 1,
		recipeSets = {
			{ name = "scrappurifier", locked = false }
		},
		subTitle = "Scrap Purifier",
		name = "Purifier",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- ScrapTreeGrower
	[tostring( obj_scrap_tree_grower )] = {
		needsPower = false,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "scraptrees", locked = false }
		},
		subTitle = "Tree Farm",
		name = "Tree Farm",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- ScrapWorkbench
	[tostring( obj_scrap_workbench )] = {
		needsPower = false,
		slots = 8,
		speed = 1,
		recipeSets = {
			{ name = "workbench", locked = false },
			{ name = "scrapworkbench", locked = false },
			{ name = "quest1", locked = true },
			{ name = "questsail", locked = true },
			{ name = "questpropeller", locked = true },
			{ name = "questveggies", locked = true },
			{ name = "questharpoon", locked = true },
			{ name = "questfinal", locked = true }
		},
		subTitle = "Workbench",
		name = "Workbench",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Apiary
	[tostring( obj_apiary )] = {
		needsPower = false,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "apiary", locked = false }
		},
		subTitle = "Apiary",
		name = "Apiary",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Seed Press
	[tostring( obj_seed_press )] = {
		needsPower = false,
		slots = 8,
		speed = 1,
		recipeSets = {
			{ name = "seedpress", locked = false }
		},
		subTitle = "Seed Press",
		name = "Seed Press",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Grill
	[tostring( obj_grill )] = {
		needsPower = false,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "grill", locked = false }
		},
		subTitle = "Grill",
		name = "Grill",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 1
	[tostring( obj_craftbot_craftbot1 )] = {
		needsPower = false,
		slots = 2,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot2 ),
		upgradeCost = 5,
		recipeSets = {
			{ name = "craftbot", locked = false },
			{ name = "scrapdecor", locked = false }
		},
		subTitle = "#{LEVEL} 1",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 2
	[tostring( obj_craftbot_craftbot2 )] = {
		needsPower = false,
		slots = 4,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot3 ),
		upgradeCost = 5,
		recipeSets = {
			{ name = "craftbot", locked = false },
			{ name = "scrapdecor", locked = false }
		},
		subTitle = "#{LEVEL} 2",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 3
	[tostring( obj_craftbot_craftbot3 )] = {
		needsPower = false,
		slots = 6,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot4 ),
		upgradeCost = 5,
		recipeSets = {
			{ name = "craftbot", locked = false },
			{ name = "scrapdecor", locked = false }
		},
		subTitle = "#{LEVEL} 3",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 4
	[tostring( obj_craftbot_craftbot4 )] = {
		needsPower = false,
		slots = 8,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot5 ),
		upgradeCost = 20,
		recipeSets = {
			{ name = "craftbot", locked = false },
			{ name = "scrapdecor", locked = false }
		},
		subTitle = "#{LEVEL} 4",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 5
	[tostring( obj_craftbot_craftbot5 )] = {
		needsPower = false,
		slots = 8,
		speed = 2,
		recipeSets = {
			{ name = "craftbot", locked = false },
			{ name = "scrapdecor", locked = false }
		},
		subTitle = "#{LEVEL} 5",
		createGuiFunction = sm.gui.createCraftBotGui
	}
}


local effectRenderables = {
	[tostring( obj_consumable_carrotburger )] = { char_cookbot_food_03, char_cookbot_food_04 },
	[tostring( obj_consumable_pizzaburger )] = { char_cookbot_food_01, char_cookbot_food_02 },
	[tostring( obj_consumable_longsandwich )] = { char_cookbot_food_02, char_cookbot_food_03 }
}

function Crafter.server_onCreate( self )
	self:sv_init()
end

function Crafter.server_onRefresh( self )
	self.crafter = nil
	self.network:setClientData( { craftArray = {}, pipeGraphs = {} })
	self:sv_init()
end

function Crafter.server_canErase( self )
	return #self.sv.craftArray == 0
end

function Crafter.client_onCreate( self )
	self:cl_init()
end

function Crafter.client_onDestroy( self )
	for _,effect in ipairs( self.cl.mainEffects ) do
		effect:destroy()
	end

	for _,effect in ipairs( self.cl.secondaryEffects ) do
		effect:destroy()
	end

	for _,effect in ipairs( self.cl.tertiaryEffects ) do
		effect:destroy()
	end

	for _,effect in ipairs( self.cl.quaternaryEffects ) do
		effect:destroy()
	end
end

function Crafter.client_onRefresh( self )
	self.crafter = nil
	self:cl_disableAllAnimations()
	self:cl_init()
end

function Crafter.client_canErase( self )
	if #self.cl.craftArray > 0 then
		sm.gui.displayAlertText( "#{INFO_BUSY}", 1.5 )
		return false
	end
	return true
end

-- Server Init

function Crafter.sv_init( self )
	self.crafter = crafters[tostring( self.shape:getShapeUuid() )]
	self.sv = {}
	self.sv.clientDataDirty = false
	self.sv.storageDataDirty = true
	self.sv.craftArray = {}
	self.sv.saved = self.storage:load()
	if self.params then print( self.params ) end

	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.spawner = self.params and self.params.spawner or nil
		self:sv_updateStorage()
	end

	if self.sv.saved.craftArray then
		self.sv.craftArray = self.sv.saved.craftArray
	end

	self:sv_buildPipesAndContainerGraph()
end

function Crafter.sv_markClientDataDirty( self )
	self.sv.clientDataDirty = true
end

function Crafter.sv_sendClientData( self )
	if self.sv.clientDataDirty then
		self.network:setClientData( { craftArray = self.sv.craftArray, pipeGraphs = self.sv.pipeGraphs, tree = self.sv.saved.tree } )
		self.sv.clientDataDirty = false
	end
end

function Crafter.sv_markStorageDirty( self )
	self.sv.storageDataDirty = true
end

function Crafter.sv_updateStorage( self )
	if self.sv.storageDataDirty then
		self.sv.saved.craftArray = self.sv.craftArray
		self.storage:save( self.sv.saved )
		self.sv.storageDataDirty = false
	end
end

function Crafter.sv_buildPipesAndContainerGraph( self )

	self.sv.pipeGraphs = { output = { containers = {}, pipes = {} }, input = { containers = {}, pipes = {} } }

	local function fnOnContainerWithFilter( vertex, parent, fnFilter, graph )
		local container = {
			shape = vertex.shape,
			distance = vertex.distance,
			shapesOnContainerPath = vertex.shapesOnPath
		}
		if parent.distance == 0 then -- Our parent is the craftbot
			local shapeInCrafterPos = parent.shape:transformPoint( vertex.shape:getWorldPosition() )
			if not fnFilter( shapeInCrafterPos.x ) then
				return false
			end
		end
		table.insert( graph.containers, container )
		return true
	end

	local function fnOnPipeWithFilter( vertex, parent, fnFilter, graph )
		local pipe = {
			shape = vertex.shape,
			state = PipeState.off
		}
		if parent.distance == 0 then -- Our parent is the craftbot
			local shapeInCrafterPos = parent.shape:transformPoint( vertex.shape:getWorldPosition() )
			if not fnFilter( shapeInCrafterPos.x ) then
				return false
			end
		end
		table.insert( graph.pipes, pipe )
		return true
	end

	-- Construct the input graph
	local function fnOnVertex( vertex, parent )
		if isAnyOf( vertex.shape:getShapeUuid(), ContainerUuids ) then -- Is Container
			assert( vertex.shape:getInteractable():getContainer() )
			return fnOnContainerWithFilter( vertex, parent, function( value ) return value <= 0 end, self.sv.pipeGraphs["input"] )
		elseif isAnyOf( vertex.shape:getShapeUuid(), PipeUuids ) then -- Is Pipe
			return fnOnPipeWithFilter( vertex, parent, function( value ) return value <= 0 end, self.sv.pipeGraphs["input"] )
		end
		return true
	end

	ConstructPipedShapeGraph( self.shape, fnOnVertex )

	-- Construct the output graph
	local function fnOnVertex( vertex, parent )
		if isAnyOf( vertex.shape:getShapeUuid(), ContainerUuids ) then -- Is Container
			assert( vertex.shape:getInteractable():getContainer() )
			return fnOnContainerWithFilter( vertex, parent, function( value ) return value > 0 end, self.sv.pipeGraphs["output"] )
		elseif isAnyOf( vertex.shape:getShapeUuid(), PipeUuids ) then -- Is Pipe
			return fnOnPipeWithFilter( vertex, parent, function( value ) return value > 0 end, self.sv.pipeGraphs["output"] )
		end
		return true
	end

	ConstructPipedShapeGraph( self.shape, fnOnVertex )

	table.sort( self.sv.pipeGraphs["input"].containers, function(a, b) return a.distance < b.distance end )
	table.sort( self.sv.pipeGraphs["output"].containers, function(a, b) return a.distance < b.distance end )

	for _, container in ipairs( self.sv.pipeGraphs["input"].containers ) do
		for _, shape in ipairs( container.shapesOnContainerPath ) do
			for _, pipe in ipairs( self.sv.pipeGraphs["input"].pipes ) do
				if pipe.shape:getId() == shape:getId() then
					pipe.state = PipeState.connected
				end
			end
		end
	end


	for _, container in ipairs( self.sv.pipeGraphs["output"].containers ) do
		for _, shape in ipairs( container.shapesOnContainerPath ) do
			for _, pipe in ipairs( self.sv.pipeGraphs["output"].pipes ) do
				if pipe.shape:getId() == shape:getId() then
					pipe.state = PipeState.connected
				end
			end
		end
	end

	self:sv_markClientDataDirty()
end

-- Client Init

function Crafter.cl_init( self )
	local shapeUuid = self.shape:getShapeUuid()
	if self.crafter == nil then
		self.crafter = crafters[tostring( shapeUuid )]
	end
	self.cl = {}
	self.cl.craftArray = {}
	self.cl.uvFrame = 0
	self.cl.animState = nil
	self.cl.animName = nil
	self.cl.animDuration = 1
	self.cl.animTime = 0

	self.cl.currentMainEffect = nil
	self.cl.currentSecondaryEffect = nil
	self.cl.currentTertiaryEffect = nil
	self.cl.currentQuaternaryEffect = nil

	self.cl.mainEffects = {}
	self.cl.secondaryEffects = {}
	self.cl.tertiaryEffects = {}
	self.cl.quaternaryEffects = {}

	if shapeUuid == obj_craftbot_craftbot1 or shapeUuid == obj_craftbot_craftbot2 or shapeUuid == obj_craftbot_craftbot3 or shapeUuid == obj_craftbot_craftbot4 or shapeUuid == obj_craftbot_craftbot5  then
		self.cl.mainEffects["unfold"] = sm.effect.createEffect( "Craftbot - Unpack", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Craftbot - Idle", self.interactable )
		self.cl.mainEffects["idlespecial01"] = sm.effect.createEffect( "Craftbot - IdleSpecial01", self.interactable )
		self.cl.mainEffects["idlespecial02"] = sm.effect.createEffect( "Craftbot - IdleSpecial02", self.interactable )
		self.cl.mainEffects["craft_start"] = sm.effect.createEffect( "Craftbot - Start", self.interactable )
		self.cl.mainEffects["craft_loop01"] = sm.effect.createEffect( "Craftbot - Work01", self.interactable )
		self.cl.mainEffects["craft_loop02"] = sm.effect.createEffect( "Craftbot - Work02", self.interactable )
		self.cl.mainEffects["craft_finish"] = sm.effect.createEffect( "Craftbot - Finish", self.interactable )

		self.cl.secondaryEffects["craft_loop01"] = sm.effect.createEffect( "Craftbot - Work", self.interactable )
		self.cl.secondaryEffects["craft_loop02"] = self.cl.secondaryEffects["craft_loop01"]
		self.cl.secondaryEffects["craft_loop03"] = self.cl.secondaryEffects["craft_loop01"]

		self.cl.tertiaryEffects["craft_loop02"] = sm.effect.createEffect( "Craftbot - Work02Torch", self.interactable, "l_arm03_jnt" )

	elseif shapeUuid == obj_craftbot_cookbot then

		self.cl.mainEffects["unfold"] = sm.effect.createEffect( "Cookbot - Unpack", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Cookbot - Idle", self.interactable )
		self.cl.mainEffects["idlespecial01"] = sm.effect.createEffect( "Cookbot - IdleSpecial01", self.interactable )
		self.cl.mainEffects["idlespecial02"] = sm.effect.createEffect( "Cookbot - IdleSpecial02", self.interactable )
		self.cl.mainEffects["craft_start"] = sm.effect.createEffect( "Cookbot - Start", self.interactable )
		self.cl.mainEffects["craft_loop01"] = sm.effect.createEffect( "Cookbot - Work01", self.interactable )
		self.cl.mainEffects["craft_loop02"] = sm.effect.createEffect( "Cookbot - Work02", self.interactable )
		self.cl.mainEffects["craft_loop03"] = sm.effect.createEffect( "Cookbot - Work03", self.interactable )
		self.cl.mainEffects["craft_finish"] = sm.effect.createEffect( "Cookbot - Finish", self.interactable )

		self.cl.secondaryEffects["craft_loop01"] = sm.effect.createEffect( "Cookbot - Work", self.interactable )
		self.cl.secondaryEffects["craft_loop02"] = self.cl.secondaryEffects["craft_loop01"]
		self.cl.secondaryEffects["craft_loop03"] = sm.effect.createEffect( "Cookbot - Work03Salt", self.interactable, "shaker_jnt" )

		self.cl.tertiaryEffects["craft_start"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_loop01"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_loop02"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_loop03"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_finish"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )

		self.cl.quaternaryEffects["craft_start"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_loop01"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_loop02"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_loop03"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_finish"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )


	elseif shapeUuid == obj_survivalobject_workbench then

		self.cl.mainEffects["craft_loop"] = sm.effect.createEffect( "Workbench - Work01", self.interactable )
		self.cl.mainEffects["craft_finish"] = sm.effect.createEffect( "Workbench - Finish", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Workbench - Idle", self.interactable )

	elseif shapeUuid == obj_survivalobject_dispenserbot then

		self.cl.mainEffects["craft_loop"] = sm.effect.createEffect( "Dispenserbot - Work01", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Workbench - Idle", self.interactable )
	

	--raft
	--TODO Don't create an effect for every crop, just set the uuid of the effect. I'm so stupid...
	elseif shapeUuid == obj_scrap_purifier then
		self.cl.mainEffects["fire"] = sm.effect.createEffect( "Fire - purifier", self.interactable )
	elseif shapeUuid == obj_apiary then
		self.cl.mainEffects["bees"] = sm.effect.createEffect( "beehive - beeswarm", self.interactable )
	elseif shapeUuid == obj_scrap_field or shapeUuid == obj_large_field then
		for _, crop in ipairs(crops) do
			self.cl.mainEffects[tostring(crop)] = sm.effect.createEffect("ShapeRenderable", self.interactable)
			self.cl.mainEffects[tostring(crop)]:setParameter("uuid", crop)
			if shapeUuid == obj_large_field then
				self.cl.mainEffects[tostring(crop).."1"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
				self.cl.mainEffects[tostring(crop).."1"]:setParameter("uuid", crop)
			end
		end

		self.cl.mainEffects["fertilizer"] = sm.effect.createEffect( "Plants - Fertilizer", self.interactable )
		self.cl.mainEffects["fertilizer1"] = sm.effect.createEffect( "Plants - Fertilizer", self.interactable )
	elseif shapeUuid == obj_scrap_tree_grower then
		self.cl.mainEffects["spruce1"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["spruce1"]:setParameter("uuid", obj_harvests_trees_spruce01_p05)
		self.cl.mainEffects["spruce2"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["spruce2"]:setParameter("uuid", obj_harvests_trees_spruce02_p05)
		self.cl.mainEffects["spruce3"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["spruce3"]:setParameter("uuid", obj_harvests_trees_spruce03_p05)

		self.cl.mainEffects["leafy1"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["leafy1"]:setParameter("uuid", obj_harvests_trees_leafy01_p04)
		self.cl.mainEffects["leafy2"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["leafy2"]:setParameter("uuid", obj_harvests_trees_leafy02_p07)
		self.cl.mainEffects["leafy3"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["leafy3"]:setParameter("uuid", obj_harvests_trees_leafy03_p09)

		self.cl.mainEffects["birch1"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["birch1"]:setParameter("uuid", obj_harvests_trees_birch01_p05)
		self.cl.mainEffects["birch2"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["birch2"]:setParameter("uuid", obj_harvests_trees_birch02_p06)
		self.cl.mainEffects["birch3"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["birch3"]:setParameter("uuid", obj_harvests_trees_birch03_p06)

		self.cl.mainEffects["pine1"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["pine1"]:setParameter("uuid", obj_harvests_trees_pine01_p11)
		self.cl.mainEffects["pine2"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["pine2"]:setParameter("uuid", obj_harvests_trees_pine02_p10)
		self.cl.mainEffects["pine3"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
		self.cl.mainEffects["pine3"]:setParameter("uuid", obj_harvests_trees_pine03_p10)

		self.cl.mainEffects["fertilizer"] = sm.effect.createEffect( "Plants - Fertilizer", self.interactable )
		self.cl.mainEffects["fertilizer"]:setOffsetPosition(sm.vec3.new(0,0.75,0))

	elseif shapeUuid == obj_grill then
		self.cl.mainEffects["fire"] = sm.effect.createEffect( "Fire - small01", self.interactable )
		self.cl.mainEffects["fish"] = sm.effect.createEffect("ShapeRenderable", self.interactable)
	elseif shapeUuid == obj_scrap_workbench then
		self.cl.mainEffects["craft"] = sm.effect.createEffect( "Craft - scrapworkbench", self.interactable )
	elseif shapeUuid == obj_seed_press then
		self.cl.mainEffects["craft"] = sm.effect.createEffect( "Craft - seedpress", self.interactable )
	end

	self:cl_setupUI( tostring( self.shape:getShapeUuid() ) )

	self.cl.pipeGraphs = { output = { containers = {}, pipes = {} }, input = { containers = {}, pipes = {} } }

	self.cl.pipeEffectPlayer = PipeEffectPlayer()
	self.cl.pipeEffectPlayer:onCreate()
end

function Crafter.cl_setupUI( self, stringUuid )
	self.cl.guiInterface = self.crafter.createGuiFunction()

	--Raft
	if isAnyOf(self.shape:getShapeUuid(), raftbots) then
		self.cl.guiInterface:setText("CraftBot_Title", self.crafter.name)
	end
	--Raft

	self.cl.guiInterface:setButtonCallback( "Upgrade", "cl_onUpgrade" )
	self.cl.guiInterface:setGridButtonCallback( "Craft", "cl_onCraft" )
	self.cl.guiInterface:setGridButtonCallback( "Repeat", "cl_onRepeat" )
	self.cl.guiInterface:setGridButtonCallback( "Collect", "cl_onCollect" )

	self:cl_updateRecipeGrid()
end

function Crafter.cl_updateRecipeGrid( self )
	self.cl.guiInterface:clearGrid( "RecipeGrid" )
	for _, recipeSet in ipairs( self.crafter.recipeSets ) do
		print( "Adding", g_craftingRecipes[recipeSet.name].path )
		local locked = recipeSet.locked
		--raft
		if recipeSet.name == "quest1" then
			locked = not g_questManager:cl_isQuestComplete(quest_mechanic_station)
		elseif recipeSet.name == "questsail" then
			locked = not g_questManager:cl_isQuestComplete(quest_radio_interactive)
		elseif recipeSet.name == "questpropeller" then
			locked = not g_questManager:cl_isQuestComplete(quest_find_trader)
		elseif recipeSet.name == "questveggies" then
			locked = not g_questManager:cl_isQuestComplete(quest_return_to_trader1)
		elseif recipeSet.name == "questharpoon" then
			locked = not g_questManager:cl_isQuestComplete(quest_return_to_trader3)
		elseif recipeSet.name == "questfinal" then
			locked = not g_questManager:cl_isQuestComplete(quest_return_to_trader4)
		end

		self.cl.guiInterface:addGridItemsFromFile( "RecipeGrid", g_craftingRecipes[recipeSet.name].path, { locked = locked } )
	end
end

function Crafter.client_onClientDataUpdate( self, data )
	self.cl.craftArray = data.craftArray
	self.cl.pipeGraphs = data.pipeGraphs
	self.tree = data.tree

	-- Experimental needs testing
	for _, val in ipairs( self.cl.craftArray ) do
		if val.time == -1 and val.startTick then
			local estimate = max( sm.game.getServerTick() - val.startTick, 0 ) -- Estimate how long time has passed since server started crafing and client recieved craft
			val.time = estimate
		end
	end
end

-- Internal util

function Crafter.getParent( self )
	if self.crafter.needsPower then
		return self.interactable:getSingleParent()
	end
	return nil
end

function Crafter.getRecipeByIndex( self, index )

	-- Convert one dimensional index to recipeSet and recipeIndex
	local recipeName = 0
	local recipeIndex = 0
	local offset = 0
	for _, recipeSet in ipairs( self.crafter.recipeSets ) do
		assert( g_craftingRecipes[recipeSet.name].recipesByIndex )
		local recipeCount = #g_craftingRecipes[recipeSet.name].recipesByIndex

		if index <= offset + recipeCount then
			recipeIndex = index - offset
			recipeName = recipeSet.name
			break
		end
		offset = offset + recipeCount
	end
 
	print( recipeIndex )
	local recipe = g_craftingRecipes[recipeName].recipesByIndex[recipeIndex]
	assert(recipe)
	if recipe then
		return recipe, g_craftingRecipes[recipeName].locked
	end

	return nil, nil
end

-- Server

function Crafter.server_onFixedUpdate( self )
	-- If body has changed, refresh the pipe graph
	if self.shape:getBody():hasChanged( sm.game.getCurrentTick() - 1 ) then
		self:sv_buildPipesAndContainerGraph()
	end

	local parent = self:getParent()
	if not self.crafter.needsPower or ( parent and parent.active ) then
		-- Update first in array
		local update = false
		for idx, val in ipairs( self.sv.craftArray ) do
			update = true
			if val then
				local recipe = val.recipe
				local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120 -- 1s windup + 2s winddown

				if val.time < recipeCraftTime then

					-- Begin crafting new item
					if val.time == -1 then
						val.startTick = sm.game.getServerTick()

						if self.shape:getShapeUuid() == obj_scrap_tree_grower then
							self.sv.saved.tree = nil
							for _, itemId in ipairs( val.recipe.ingredientList) do
								local tree = nil
								for __, uuid in pairs(itemId) do
									if uuid == obj_sprucetree_sapling then
										tree = "spruce"
									elseif uuid == obj_leafytree_sapling then
										tree = "leafy"
									elseif uuid == obj_birchtree_sapling then
										tree = "birch"
									elseif uuid == obj_pinetree_sapling then
										tree = "pine"
									end
								end

								if not self.sv.saved.tree and tree then
									local treeType = tree..tostring(math.random(1,3))
									if treeType == "leafy1" then
										treeType = tree..tostring(math.random(2,3))
									elseif treeType == "spruce3" then
										treeType = tree..tostring(math.random(1,2))
									end
									self.sv.saved.tree = treeType
								end
							end
						end

						self:sv_markClientDataDirty()
					end

					val.time = val.time + 1
					--update craft time while unloaded
					if sm.game.getCurrentTick() > val.startTick + val.time then
						val.time = sm.game.getCurrentTick() - val.startTick
					end

					local isSpawner = self.sv.saved and self.sv.saved.spawner

					if isSpawner then
						if val.time + 10 == recipeCraftTime then
							--print( "Open the gates!" )
							self.sv.saved.spawner.active = true
						end
					end

					if val.time >= recipeCraftTime then

						if isSpawner then
							print( "Spawning {"..recipe.itemId.."}" )
							self:sv_spawn( self.sv.saved.spawner )
						end

						local containerObj = FindContainerToCollectTo( self.sv.pipeGraphs["output"].containers, sm.uuid.new( recipe.itemId ), recipe.quantity )
						if containerObj then
							sm.container.beginTransaction()
							sm.container.collect( containerObj.shape:getInteractable():getContainer(), sm.uuid.new( recipe.itemId ), recipe.quantity )
							if recipe.extras then
								print( recipe.extras )
								for _,extra in ipairs( recipe.extras ) do
									sm.container.collect( containerObj.shape:getInteractable():getContainer(), sm.uuid.new( extra.itemId ), extra.quantity )
								end
							end
							if sm.container.endTransaction() then -- Has space

								table.remove( self.sv.craftArray, idx )

								if val.loop and #self.sv.pipeGraphs["input"].containers > 0 then
									self:sv_craft( { recipe = val.recipe, loop = true } )
								end

								self:sv_markStorageDirty()
								self.network:sendToClients( "cl_n_onCollectToChest", { shapesOnContainerPath = containerObj.shapesOnContainerPath, itemId = sm.uuid.new( recipe.itemId ) } )
								-- Pass extra?
							else
								print( "Container full" )
							end
						end

					end

					--self:sv_markClientDataDirty()
					break
				end
			end
		end

		if not update then
			self.sv.saved.tree = nil
		end
	end

	self:sv_sendClientData()
	self:sv_markStorageDirty()
	self:sv_updateStorage()
end

--Client

local UV_OFFLINE = 0
local UV_READY = 1
local UV_FULL = 2
local UV_HEART = 3
local UV_WORKING_START = 4
local UV_WORKING_COUNT = 4
local UV_JAMMED_START = 8
local UV_JAMMED_COUNT = 4

function Crafter.client_onFixedUpdate( self )
	for idx, val in ipairs( self.cl.craftArray ) do
		if val then
			local recipe = val.recipe
			local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120-- 1s windup + 2s winddown

			if val.time < recipeCraftTime then
				val.time = val.time + 1

				if val.time >= recipeCraftTime and #self.cl.pipeGraphs.output.containers > 0 then
					table.remove( self.cl.craftArray, idx )
				end

				break
			end
		end
	end
end

function Crafter.client_onUpdate( self, deltaTime )

	local prevAnimState = self.cl.animState

	local craftTimeRemaining = 0
	local isCrafting = false
	local hasItems = false
	local crop = nil
	local isFertilized = false
	local craftProgress = 0
	local recipe

	local parent = self:getParent()
	if not self.crafter.needsPower or ( parent and parent.active ) then
		local guiActive = self.cl.guiInterface:isActive()

		for idx = 1, self.crafter.slots do
			local val = self.cl.craftArray[idx]
			if val then
				hasItems = true

				recipe = val.recipe
				local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120

				--raft
				craftProgress = val.time/recipeCraftTime
				crop = recipe.itemId

				for _, itemId in ipairs(recipe.ingredientList) do
					for __, uuid in pairs(itemId) do
						if uuid == obj_consumable_fertilizer then
							isFertilized = true
						end
					end
				end

				if val.time >= 0 and val.time < recipeCraftTime then -- The one beeing crafted
					isCrafting = true
					craftTimeRemaining = ( recipeCraftTime - val.time ) / 40
				end

				if guiActive and self.interactable.shape.uuid ~= obj_survivalobject_dispenserbot then
					local gridItem = {}
					gridItem.itemId = recipe.itemId
					gridItem.craftTime = recipeCraftTime
					gridItem.remainingTicks = recipeCraftTime - clamp( val.time, 0, recipeCraftTime )
					gridItem.locked = false
					gridItem.repeating = val.loop
					self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
				end
			else
				if guiActive and self.interactable.shape.uuid ~= obj_survivalobject_dispenserbot then
					local gridItem = {}
					gridItem.itemId = "00000000-0000-0000-0000-000000000000"
					gridItem.craftTime = 0
					gridItem.remainingTicks = 0
					gridItem.locked = false
					gridItem.repeating = false
					self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
				end
			end
		end

		if isCrafting then
			self.cl.animState = "craft"
			self.cl.uvFrame = self.cl.uvFrame + deltaTime * 8
			self.cl.uvFrame = self.cl.uvFrame % UV_WORKING_COUNT
			self.interactable:setUvFrameIndex( math.floor( self.cl.uvFrame ) + UV_WORKING_START )
		elseif hasItems then
			self.cl.animState = "idle"
			self.interactable:setUvFrameIndex( UV_FULL )
		else
			self.cl.animState = "idle"
			self.interactable:setUvFrameIndex( UV_READY )
		end
	else
		self.cl.animState = "offline"
		self.interactable:setUvFrameIndex( UV_OFFLINE )
	end
	
	self.cl.animTime = self.cl.animTime + deltaTime
	local animDone = false
	if self.cl.animTime > self.cl.animDuration then
		self.cl.animTime = math.fmod( self.cl.animTime, self.cl.animDuration )

		--print( "ANIMATION DONE:", self.cl.animName )
		animDone = true
	end

	local craftbotParameter = 1

	if self.cl.animState ~= prevAnimState then
		--print( "NEW ANIMATION STATE:", self.cl.animState )
	end



	--raft
	local shapeUuid = self.shape:getShapeUuid()

	if shapeUuid == obj_scrap_purifier then
		if isCrafting and not self.cl.mainEffects["fire"]:isPlaying() then
			self.cl.mainEffects["fire"]:start()
		elseif not isCrafting and self.cl.mainEffects["fire"]:isPlaying() then
			self.cl.mainEffects["fire"]:stop()
		end
	elseif shapeUuid == obj_apiary then
		if isCrafting and not self.cl.mainEffects["bees"]:isPlaying() then
			self.cl.mainEffects["bees"]:start()
		elseif not isCrafting and self.cl.mainEffects["bees"]:isPlaying() then
			self.cl.mainEffects["bees"]:stop()
		end
	elseif shapeUuid == obj_scrap_field or shapeUuid == obj_large_field then
		if crop then
			self.crop = crop
		else
			crop = self.crop
		end
		local worldPosition = self.shape:getWorldPosition()
		local worldPosition1
		local bigFarm = shapeUuid == obj_large_field
		if bigFarm then
			worldPosition = worldPosition + self.shape.at*0.5 - self.shape.right*0.35
			worldPosition1 = self.shape:getWorldPosition() + self.shape.at*0.5 + self.shape.right*0.35
		end

		--fertilizer
		if isFertilized and isCrafting and not self.cl.mainEffects["fertilizer"]:isPlaying() then
			self.cl.mainEffects["fertilizer"]:setOffsetPosition(self.shape:transformPoint(worldPosition))
			self.cl.mainEffects["fertilizer"]:start()
			if bigFarm then
				self.cl.mainEffects["fertilizer1"]:setOffsetPosition(self.shape:transformPoint(worldPosition1))
				self.cl.mainEffects["fertilizer1"]:start()
			end
		end

		local reload = false
		if hasItems and not self.cl.mainEffects[crop]:isPlaying() then
			reload = true
		end

		--growing crops
		if (isCrafting and not self.cl.mainEffects[crop]:isPlaying()) or reload then

			self.cl.mainEffects[crop]:start()
			sm.effect.playEffect( "Plants - Planted", worldPosition )
			if bigFarm then
				self.cl.mainEffects[crop.."1"]:start()
				sm.effect.playEffect( "Plants - Planted", worldPosition1 )
			end
		end

		if (crop and self.cl.mainEffects[crop]:isPlaying()) or reload then
			local offset = sm.vec3.zero()
			local rotation = self.shape:getWorldRotation()
			if crop == tostring(obj_plantables_carrot) then
				rotation = rotation * sm.vec3.getRotation( self.shape.up, self.shape.right )
				offset = self.shape.at*0.075
			elseif crop == tostring(obj_plantables_banana) then
				rotation = sm.quat.lookRotation( -self.shape.at, self.shape.right )
				rotation = rotation * sm.vec3.getRotation( -self.shape.right, self.shape.up )
			elseif crop == tostring(obj_plantables_blueberry) then
				offset = self.shape.at*0.075
			elseif crop == tostring(obj_plantables_redbeet) then
				rotation = rotation * sm.vec3.getRotation( self.shape.up, self.shape.right + self.shape.up*2 )
				offset = self.shape.at*0.075
			elseif crop == tostring(obj_resource_cotton) then
				offset = self.shape.at*0.075
			end

			self.cl.mainEffects[crop]:setScale(vec3Num(craftProgress*0.2 + 0.05))
			self.cl.mainEffects[crop]:setOffsetPosition(self.shape:transformPoint(worldPosition - self.shape.at * 0.25 * (1-craftProgress) - offset))
			self.cl.mainEffects[crop]:setOffsetRotation((self.shape:transformRotation(rotation)))
			if bigFarm then
				self.cl.mainEffects[crop.."1"]:setScale(vec3Num(craftProgress*0.2 + 0.05))
				self.cl.mainEffects[crop.."1"]:setOffsetPosition(self.shape:transformPoint(worldPosition1 - self.shape.at * 0.25 * (1-craftProgress) - offset))
				self.cl.mainEffects[crop.."1"]:setOffsetRotation((self.shape:transformRotation(rotation)))
			end
		end
	
		if craftProgress >= 1 then
			if self.cl.mainEffects["fertilizer"]:isPlaying() then
				self.cl.mainEffects["fertilizer"]:stop()
				if bigFarm then
					self.cl.mainEffects["fertilizer1"]:stop()
				end
			end
		end

		if not hasItems then
			for _, crop in ipairs(crops) do
				if self.cl.mainEffects[tostring(crop)]:isPlaying() then
					self.cl.mainEffects[tostring(crop)]:stop()
					sm.effect.playEffect( "Plants - Picked", worldPosition )
					if bigFarm then
						self.cl.mainEffects[tostring(crop).."1"]:stop()
						sm.effect.playEffect( "Plants - Picked", worldPosition1 )
					end
				end
			end
		end
		
	elseif shapeUuid == obj_scrap_tree_grower then
		worldPosition = self.shape:getWorldPosition() + self.shape.at*0.6

		--fertilizer
		if isFertilized and isCrafting and not self.cl.mainEffects["fertilizer"]:isPlaying() then
			self.cl.mainEffects["fertilizer"]:start()
		end

		local growEffect = nil
		local reload = false
		if self.tree then
			if self.cl.mainEffects[self.tree]:isPlaying() then
				growEffect = self.tree
			else
				--start grow
				growEffect = self.tree
				self.cl.mainEffects[growEffect]:start()
				sm.effect.playEffect( "Plants - Planted", worldPosition )
				reload = true
			end
		end

		if growEffect or reload then
			local offset = sm.vec3.new(0,1.0,0)
			local scale = 0.4
			if growEffect:find("spruce") then
				offset = sm.vec3.new(0,4.25,0)
				scale = 3
			end

			self.cl.mainEffects[growEffect]:setScale(vec3Num(craftProgress*0.1 + 0.0275))
			self.cl.mainEffects[growEffect]:setOffsetPosition(sm.vec3.new(0,-1,0) * scale * (1-craftProgress) + offset)
		end

		if craftProgress >= 1 then
			if self.cl.mainEffects["fertilizer"]:isPlaying() then
				self.cl.mainEffects["fertilizer"]:stop()
			end
		end

		if not hasItems then
			local trees = {"birch", "leafy", "pine", "spruce"}
			for _, tree in ipairs(trees) do
				for i=1,3 do
					if self.cl.mainEffects[tree..tostring(i)]:isPlaying() then
						self.cl.mainEffects[tree..tostring(i)]:stop()
						sm.effect.playEffect( "Plants - Picked", worldPosition )
					end
				end
			end
		end
	elseif shapeUuid == obj_grill then
		if crop then
			self.crop = crop
		end
		if isCrafting and not self.cl.mainEffects["fire"]:isPlaying() then
			self.cl.mainEffects["fire"]:start()

			local fish = sm.uuid.new(crop)
			for _, itemId in ipairs(recipe.ingredientList) do
				for __, uuid in pairs(itemId) do
					if uuid ~= blk_scrapwood and type(uuid) ~= "number" then
						fish = uuid
					end
				end		
			end

			self.cl.mainEffects["fish"]:setParameter("uuid", fish)
			self.cl.mainEffects["fish"]:setScale(vec3Num(0.5))					
			self.cl.mainEffects["fish"]:setOffsetPosition(sm.vec3.new(0,0.375,0))

			local rotation = self.shape:getWorldRotation() * sm.vec3.getRotation( self.shape.up, self.shape.right )
			rotation = rotation *sm.quat.lookRotation(sm.vec3.new(0,1,0), sm.vec3.new(0,0,1) )
			rotation = self.shape:transformRotation(rotation)
			self.cl.mainEffects["fish"]:setOffsetRotation(rotation)
			self.cl.mainEffects["fish"]:start()

		elseif not isCrafting and self.cl.mainEffects["fire"]:isPlaying() then
			self.cl.mainEffects["fire"]:stop()
			self.cl.mainEffects["fish"]:stop()
			
		elseif not isCrafting and hasItems then
			self.cl.mainEffects["fish"]:setParameter("uuid", sm.uuid.new(self.crop))
			self.cl.mainEffects["fish"]:setScale(vec3Num(0.5))

			if not self.cl.mainEffects["fish"]:isPlaying() then
				self.cl.mainEffects["fish"]:setOffsetPosition(sm.vec3.new(0,0.475,0))
				local rotation = self.shape:getWorldRotation() * sm.quat.lookRotation(sm.vec3.new(1,0,0), sm.vec3.new(0,1,0) )
				rotation = self.shape:transformRotation(rotation)
				self.cl.mainEffects["fish"]:setOffsetRotation(rotation)
				self.cl.mainEffects["fish"]:start()
			end
	
		elseif not isCrafting and not hasItems and self.cl.mainEffects["fish"]:isPlaying() then
			self.cl.mainEffects["fish"]:stop()
		end
	elseif shapeUuid == obj_scrap_workbench or shapeUuid == obj_seed_press then
		if isCrafting and not self.cl.mainEffects["craft"]:isPlaying() then
			self.cl.mainEffects["craft"]:start()
		elseif not isCrafting and self.cl.mainEffects["craft"]:isPlaying() then
			self.cl.mainEffects["craft"]:stop()
		end
	end

	if isAnyOf( shapeUuid, raftbots) then
		return
	end




	local prevAnimName = self.cl.animName

	
	if self.cl.animState == "offline" then
		assert( self.crafter.needsPower )
		self.cl.animName = "offline"

	elseif self.cl.animState == "idle" then
		if self.cl.animName == "offline" or self.cl.animName == nil then
			if self.crafter.needsPower then
				self.cl.animName = "turnon"
			else
				self.cl.animName = "unfold"
			end
			animDone = true
		elseif self.cl.animName == "turnon" or self.cl.animName == "unfold" or self.cl.animName == "craft_finish" then
			if animDone then
				self.cl.animName = "idle"
			end
		elseif self.cl.animName == "idle" then
			if animDone then
				local rand = math.random( 1, 5 )
				if rand == 1 then
					self.cl.animName = "idlespecial01"
				elseif rand == 2 then
					self.cl.animName = "idlespecial02"
				else
					self.cl.animName = "idle"
				end
			end
		elseif self.cl.animName == "idlespecial01" or self.cl.animName == "idlespecial02" then
			if animDone then
				self.cl.animName = "idle"
			end
		else
			--assert( self.cl.animName == "craft_finish" )
			if animDone then
				self.cl.animName = "idle"
			end
		end

	elseif self.cl.animState == "craft" then
		if self.cl.animName == "idle" or self.cl.animName == "idlespecial01" or self.cl.animName == "idlespecial02" or self.cl.animName == "turnon" or self.cl.animName == "unfold" or self.cl.animName == nil then
			self.cl.animName = "craft_start"
			animDone = true

		elseif self.cl.animName == "craft_start" then
			if animDone then
				if self.interactable:hasAnim( "craft_loop" ) then
					self.cl.animName = "craft_loop"
				else
					self.cl.animName = "craft_loop01"
				end
			end

		elseif self.cl.animName == "craft_loop" then
			if animDone then
				if craftTimeRemaining <= 2 then
					self.cl.animName = "craft_finish"
				else
					--keep looping
				end
			end

		elseif self.cl.animName == "craft_loop01" or self.cl.animName == "craft_loop02" or self.cl.animName == "craft_loop03" then
			if animDone then
				if craftTimeRemaining <= 2 then
					self.cl.animName = "craft_finish"
				else
					local rand = math.random( 1, 4 )
					if rand == 1 and craftTimeRemaining >= self.interactable:getAnimDuration( "craft_loop02" ) then
						self.cl.animName = "craft_loop02"
						craftbotParameter = 2
					elseif rand == 2 and craftTimeRemaining >= self.interactable:getAnimDuration( "craft_loop03" ) then
						self.cl.animName = "craft_loop03"
						craftbotParameter = 3
					else
						self.cl.animName = "craft_loop01"
						craftbotParameter = 1
					end
				end
			end

		elseif self.cl.animName == "craft_finish" then
			if animDone then
				self.cl.animName = "craft_start"
			end

		end
	end

	if self.cl.animName ~= prevAnimName then
		--print( "NEW ANIMATION:", self.cl.animName )

		if prevAnimName then
			self.interactable:setAnimEnabled( prevAnimName, false )
			self.interactable:setAnimProgress( prevAnimName, 0 )
		end

		self.cl.animDuration = self.interactable:getAnimDuration( self.cl.animName )
		self.cl.animTime = 0

		--print( "DURATION:", self.cl.animDuration )

		self.interactable:setAnimEnabled( self.cl.animName, true )
	end

	if animDone then

		local mainEffect = self.cl.mainEffects[self.cl.animName]
		local secondaryEffect = self.cl.secondaryEffects[self.cl.animName]
		local tertiaryEffect = self.cl.tertiaryEffects[self.cl.animName]
		local quaternaryEffect = self.cl.quaternaryEffects[self.cl.animName]

		if mainEffect ~= self.cl.currentMainEffect then

			if self.cl.currentMainEffect ~= self.cl.mainEffects["craft_finish"] then
				if self.cl.currentMainEffect then
					self.cl.currentMainEffect:stop()
				end
			end
			self.cl.currentMainEffect = mainEffect
		end

		if secondaryEffect ~= self.cl.currentSecondaryEffect then

			if self.cl.currentSecondaryEffect then
				self.cl.currentSecondaryEffect:stop()
			end

			self.cl.currentSecondaryEffect = secondaryEffect
		end

		if tertiaryEffect ~= self.cl.currentTertiaryEffect then

			if self.cl.currentTertiaryEffect then
				self.cl.currentTertiaryEffect:stop()
			end

			self.cl.currentTertiaryEffect = tertiaryEffect
		end

		if quaternaryEffect ~= self.cl.currentQuaternaryEffect then

			if self.cl.currentQuaternaryEffect then
				self.cl.currentQuaternaryEffect:stop()
			end

			self.cl.currentQuaternaryEffect = quaternaryEffect
		end

		if self.cl.currentMainEffect then
			self.cl.currentMainEffect:setParameter( "craftbot", craftbotParameter )

			if not self.cl.currentMainEffect:isPlaying() then
				self.cl.currentMainEffect:start()
			end
		end

		if self.cl.currentSecondaryEffect then
			self.cl.currentSecondaryEffect:setParameter( "craftbot", craftbotParameter )

			if not self.cl.currentSecondaryEffect:isPlaying() then
				self.cl.currentSecondaryEffect:start()
			end
		end

		if self.cl.currentTertiaryEffect then
			self.cl.currentTertiaryEffect:setParameter( "craftbot", craftbotParameter )

			if self.shape:getShapeUuid() == obj_craftbot_cookbot then
				local val = self.cl.craftArray and self.cl.craftArray[1] or nil
				if val then
					local cookbotRenderables = effectRenderables[val.recipe.itemId]
					if cookbotRenderables and cookbotRenderables[1] then
						self.cl.currentTertiaryEffect:setParameter( "uuid", cookbotRenderables[1] )
						self.cl.currentTertiaryEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
					end
				end
			end

			if not self.cl.currentTertiaryEffect:isPlaying() then
				self.cl.currentTertiaryEffect:start()
			end
		end

		if self.cl.currentQuaternaryEffect then
			self.cl.currentQuaternaryEffect:setParameter( "craftbot", craftbotParameter )

			if self.shape:getShapeUuid() == obj_craftbot_cookbot then
				local val = self.cl.craftArray and self.cl.craftArray[1] or nil
				if val then
					local cookbotRenderables = effectRenderables[val.recipe.itemId]
					if cookbotRenderables and cookbotRenderables[2] then
						self.cl.currentQuaternaryEffect:setParameter( "uuid", cookbotRenderables[2] )
						self.cl.currentQuaternaryEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
					end
				end
			end

			if not self.cl.currentQuaternaryEffect:isPlaying() then
				self.cl.currentQuaternaryEffect:start()
			end
		end
	end
	assert(self.cl.animName)
	self.interactable:setAnimProgress( self.cl.animName, self.cl.animTime / self.cl.animDuration )

	-- Pipe visualization

	if self.cl.pipeGraphs.input then
		LightUpPipes( self.cl.pipeGraphs.input.pipes )
	end

	if self.cl.pipeGraphs.output then
		LightUpPipes( self.cl.pipeGraphs.output.pipes )
	end

	self.cl.pipeEffectPlayer:update( deltaTime )
end

function Crafter.cl_disableAllAnimations( self )
	if self.interactable:hasAnim( "turnon" ) then
		self.interactable:setAnimEnabled( "turnon", false )
	else
		self.interactable:setAnimEnabled( "unfold", false )
	end
	self.interactable:setAnimEnabled( "idle", false )
	self.interactable:setAnimEnabled( "idlespecial01", false )
	self.interactable:setAnimEnabled( "idlespecial02", false )
	self.interactable:setAnimEnabled( "craft_start", false )
	if self.interactable:hasAnim( "craft_loop" ) then
		self.interactable:setAnimEnabled( "craft_loop", false )
	else
		self.interactable:setAnimEnabled( "craft_loop01", false )
		self.interactable:setAnimEnabled( "craft_loop02", false )
		self.interactable:setAnimEnabled( "craft_loop03", false )
	end
	self.interactable:setAnimEnabled( "craft_finish", false )
	self.interactable:setAnimEnabled( "aimbend_updown", false )
	self.interactable:setAnimEnabled( "aimbend_leftright", false )
	self.interactable:setAnimEnabled( "offline", false )
end

function Crafter.client_canInteract( self )
	local parent = self:getParent()
	if not self.crafter.needsPower or ( parent and parent.active ) then
		sm.gui.setCenterIcon( "Use" )
		local keyBindingText =  sm.gui.getKeyBinding( "Use", true )
		sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_USE}" )
	else
		sm.gui.setCenterIcon( "Hit" )
		sm.gui.setInteractionText( "#{INFO_REQUIRES_POWER}" )
		return false
	end
	return true
end

function Crafter.cl_setGuiContainers( self )

	craftbots = { obj_craftbot_craftbot1, obj_craftbot_craftbot2, obj_craftbot_craftbot3, obj_craftbot_craftbot4, obj_craftbot_craftbot5 }

	if isAnyOf( self.shape:getShapeUuid(), craftbots) or isAnyOf( self.shape:getShapeUuid(), raftbots) then
		local containers = {}
		if #self.cl.pipeGraphs.input.containers > 0 then
			for _, val in ipairs( self.cl.pipeGraphs.input.containers ) do
				table.insert( containers, val.shape:getInteractable():getContainer( 0 ) )
			end
		else
			table.insert( containers, sm.localPlayer.getPlayer():getInventory() )
		end
		self.cl.guiInterface:setContainers( "", containers )
	else
		self.cl.guiInterface:setContainer( "", sm.localPlayer.getPlayer():getInventory() )
	end
end

function Crafter.client_onInteract( self, character, state )
	if state == true then
		self:cl_updateRecipeGrid()
		local parent = self:getParent()
		if not self.crafter.needsPower or ( parent and parent.active ) then

			self:cl_setGuiContainers()

			if self.interactable.shape.uuid ~= obj_survivalobject_dispenserbot then
				for idx = 1, self.crafter.slots do
					local val = self.cl.craftArray[idx]
					if val then
						local recipe = val.recipe
						local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120

						local gridItem = {}
						gridItem.itemId = recipe.itemId
						gridItem.craftTime = recipeCraftTime
						gridItem.remainingTicks = recipeCraftTime - clamp( val.time, 0, recipeCraftTime )
						gridItem.locked = false
						gridItem.repeating = val.loop
						self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )

					else
						local gridItem = {}
						gridItem.itemId = "00000000-0000-0000-0000-000000000000"
						gridItem.craftTime = 0
						gridItem.remainingTicks = 0
						gridItem.locked = false
						gridItem.repeating = false
						self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
					end
				end

				if self.crafter.slots < 8 then
					local shapeUuid = self.shape:getShapeUuid()

					local gridItem = {}
					gridItem.locked = true

					if shapeUuid == obj_craftbot_craftbot1 then

						gridItem.unlockLevel = 2

						self.cl.guiInterface:setGridItem( "ProcessGrid", 2, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 3, gridItem )

						gridItem.unlockLevel = 3

						self.cl.guiInterface:setGridItem( "ProcessGrid", 4, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 5, gridItem )

						gridItem.unlockLevel = 4

						self.cl.guiInterface:setGridItem( "ProcessGrid", 6, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 7, gridItem )

					elseif shapeUuid == obj_craftbot_craftbot2 then

						gridItem.unlockLevel = 3

						self.cl.guiInterface:setGridItem( "ProcessGrid", 4, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 5, gridItem )

						gridItem.unlockLevel = 4

						self.cl.guiInterface:setGridItem( "ProcessGrid", 6, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 7, gridItem )

					elseif shapeUuid == obj_craftbot_craftbot3 then
						
						gridItem.unlockLevel = 4

						self.cl.guiInterface:setGridItem( "ProcessGrid", 6, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 7, gridItem )

					end
				end
			end

			self.cl.guiInterface:setText( "SubTitle", self.crafter.subTitle )
			self.cl.guiInterface:open()

			local pipeConnection = #self.cl.pipeGraphs.output.containers > 0

			self.cl.guiInterface:setVisible( "PipeConnection", pipeConnection )

			if self.crafter.upgradeCost then
				if not sm.game.getEnableUpgradeCost() then
					self.cl.guiInterface:setData( "Upgrade", { cost = self.crafter.upgradeCost, available = 1000 } )
				else		
					local upgradeData = {}
					upgradeData.cost = self.crafter.upgradeCost
					upgradeData.available = sm.container.totalQuantity( sm.localPlayer.getPlayer():getInventory(), obj_consumable_component )
					self.cl.guiInterface:setData( "Upgrade", upgradeData )
				end
			else
				self.cl.guiInterface:setVisible( "Upgrade", false )
			end
		end

		if self.crafter.upgrade then
			local nextLevel = crafters[ self.crafter.upgrade ]
			local upgradeInfo = {}
			local nextLevelSlots = nextLevel.slots - self.crafter.slots
			if nextLevelSlots > 0 then
				upgradeInfo["Slots"] = nextLevelSlots
			end
			local nextLevelSpeed = nextLevel.speed - self.crafter.speed
			if nextLevelSpeed > 0 then
				upgradeInfo["Speed"] = nextLevelSpeed
			end
			self.cl.guiInterface:setData( "UpgradeInfo", upgradeInfo )
		else
			self.cl.guiInterface:setData( "UpgradeInfo", nil )
		end
	end
end

-- Gui callbacks

function Crafter.cl_onCraft( self, buttonName, index, data )
	print( "ONCRAFT", index )
	local _, locked = self:getRecipeByIndex( index + 1 )
	if locked then
		print( "Recipe is locked" )
	else
		self.network:sendToServer( "sv_n_craft", { index = index + 1 } )
	end
end

function Crafter.sv_n_craft( self, params, player )
	local recipe, locked = self:getRecipeByIndex( params.index )
	if locked then
		print( "Recipe is locked" )
	else
		self:sv_craft( { recipe = recipe }, player )
	end
end

function Crafter.sv_craft( self, params, player )
	if #self.sv.craftArray < self.crafter.slots then
		local recipe = params.recipe

		-- Charge container
		sm.container.beginTransaction()

		local containerArray = {}
		local hasInputContainers = #self.sv.pipeGraphs.input.containers > 0

		for _, ingredient in ipairs( recipe.ingredientList ) do
			if hasInputContainers then

				local consumeCount = ingredient.quantity

				for _, container in ipairs( self.sv.pipeGraphs.input.containers ) do
					if consumeCount > 0 then
						consumeCount = consumeCount - sm.container.spend( container.shape:getInteractable():getContainer(), ingredient.itemId, consumeCount, false )
						table.insert( containerArray, { shapesOnContainerPath = container.shapesOnContainerPath, itemId = ingredient.itemId } )
					else
						break
					end
				end

				if consumeCount > 0 then
					print("Could not consume enough of ", ingredient.itemId, " Needed ", consumeCount, " more")
					sm.container.abortTransaction()
					return
				end
			else
				if player and sm.game.getLimitedInventory() then
					sm.container.spend( player:getInventory(), ingredient.itemId, ingredient.quantity )
				end
			end
		end


		if sm.container.endTransaction() then -- Can afford
			print( "Crafting:", recipe.itemId, "x"..recipe.quantity )

			table.insert( self.sv.craftArray, { recipe = recipe, time = -1, loop = params.loop or false } )

			self:sv_markStorageDirty()
			self:sv_markClientDataDirty()

			if #containerArray > 0 then
				self.network:sendToClients( "cl_n_onCraftFromChest", containerArray )
			end
		else
			print( "Can't afford to craft" )
		end
	else
		print( "Craft queue full" )
	end
end

function Crafter.cl_n_onCraftFromChest( self, params )
	for _, tbl in ipairs( params ) do
		local shapeList = {}
		for _, shape in reverse_ipairs( tbl.shapesOnContainerPath ) do
			table.insert( shapeList, shape )
		end

		local endNode = PipeEffectNode()
		endNode.shape = self.shape
		endNode.point = sm.vec3.new( -5.0, -2.5, 0.0 ) * sm.construction.constants.subdivideRatio
		table.insert( shapeList, endNode )

		self.cl.pipeEffectPlayer:pushShapeEffectTask( shapeList, tbl.itemId )
	end
end

function Crafter.cl_n_onCollectToChest( self, params )

	local startNode = PipeEffectNode()
	startNode.shape = self.shape
	startNode.point = sm.vec3.new( 5.0, -2.5, 0.0 ) * sm.construction.constants.subdivideRatio
	table.insert( params.shapesOnContainerPath, 1, startNode)

	self.cl.pipeEffectPlayer:pushShapeEffectTask( params.shapesOnContainerPath, params.itemId )
end

function Crafter.cl_onRepeat( self, buttonName, index, gridItem )
	print( "Repeat pressed", index )
	self.network:sendToServer( "sv_n_repeat", { slot = index } )
end

function Crafter.cl_onCollect( self, buttonName, index, gridItem )
	self.network:sendToServer( "sv_n_collect", { slot = index } )
end

function Crafter.sv_n_repeat( self, params )
	local val = self.sv.craftArray[params.slot + 1]
	if val then
		val.loop = not val.loop
		self:sv_markStorageDirty()
		self:sv_markClientDataDirty()
	end
end

function Crafter.sv_n_collect( self, params, player )
	local val = self.sv.craftArray[params.slot + 1]
	if val then
		local recipe = val.recipe
		if val.time >= math.ceil( recipe.craftTime / self.crafter.speed ) then
			print( "Collecting "..recipe.quantity.."x {"..recipe.itemId.."} to container", player:getInventory() )

			sm.container.beginTransaction()
			sm.container.collect( player:getInventory(), sm.uuid.new( recipe.itemId ), recipe.quantity )
			if recipe.extras then
				print( recipe.extras )
				for _,extra in ipairs( recipe.extras ) do
					sm.container.collect( player:getInventory(), sm.uuid.new( extra.itemId ), extra.quantity )
				end
			end
			if sm.container.endTransaction() then -- Has space
				table.remove( self.sv.craftArray, params.slot + 1 )
				self:sv_markStorageDirty()
				self:sv_markClientDataDirty()
			else
				self.network:sendToClient( player, "cl_n_onMessage", "#{INFO_INVENTORY_FULL}" )
			end
		else
			print( "Not done" )
		end
	end
end

function Crafter.sv_spawn( self, spawner )
	print( spawner )

	local val = self.sv.craftArray[1]
	local recipe = val.recipe
	assert( recipe.quantity == 1 )

	local uid = sm.uuid.new( recipe.itemId )
	local rotation = sm.quat.angleAxis( math.pi*0.5, sm.vec3.new( 1, 0, 0 ) )
	local size = rotation * sm.item.getShapeSize( uid )
	local spawnPoint = self.sv.saved.spawner.shape:getWorldPosition() + sm.vec3.new( 0, 0, -1.5 ) - size * sm.vec3.new( 0.125, 0.125, 0.25 )
	local shapeLocalRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), sm.vec3.new( 0, 1, 0 ) )
	local body = sm.body.createBody( spawnPoint, rotation * shapeLocalRotation, true )
	local shape = body:createPart( uid, sm.vec3.new( 0, 0, 0), sm.vec3.new( 0, -1, 0 ), sm.vec3.new( 1, 0, 0 ), true )

	table.remove( self.sv.craftArray, 1 )
	self:sv_markStorageDirty()
	self:sv_markClientDataDirty()

end

function Crafter.cl_onUpgrade( self, buttonName )
	self.network:sendToServer( "sv_n_upgrade" )
end

function Crafter.sv_n_upgrade( self, params, player )
	print( "Upgrading" )
	local function fnUpgrade()
		local upgrade = self.crafter.upgrade
		self.crafter = crafters[upgrade]
		self.network:sendToClients( "cl_n_upgrade", upgrade )
		self.shape:replaceShape( sm.uuid.new( upgrade ) )
	end

	if not sm.game.getEnableUpgradeCost() then
		fnUpgrade()
	else
		if self.crafter.upgrade then
			if sm.container.beginTransaction() then
				sm.container.spend( player:getInventory(), obj_consumable_component, self.crafter.upgradeCost, true )
				if sm.container.endTransaction() then
					fnUpgrade()
				end
			end
		else
			print( "Can't be upgraded" )
		end
	end
end

function Crafter.cl_n_upgrade( self, upgrade )
	print( "Client Upgrading" )
	if not sm.isHost then
		self.crafter = crafters[upgrade]
	end
	self:cl_updateRecipeGrid()

	if self.cl.guiInterface:isActive() then

		if self.crafter.upgradeCost then			
			if not sm.game.getEnableUpgradeCost() then
				self.cl.guiInterface:setData( "Upgrade", { cost = self.crafter.upgradeCost, available = 1000 } )
			else
				local upgradeData = {}
				upgradeData.cost = self.crafter.upgradeCost
				upgradeData.available = sm.container.totalQuantity( sm.localPlayer.getPlayer():getInventory(), obj_consumable_component )
				self.cl.guiInterface:setData( "Upgrade", upgradeData )
			end
		else
			self.cl.guiInterface:setVisible( "Upgrade", false )
		end

		self.cl.guiInterface:setText( "SubTitle", self.crafter.subTitle )

		if self.crafter.upgrade then
			local nextLevel = crafters[ self.crafter.upgrade ]
			local upgradeInfo = {}
			local nextLevelSlots = nextLevel.slots - self.crafter.slots
			if nextLevelSlots > 0 then
				upgradeInfo["Slots"] = nextLevelSlots
			end
			local nextLevelSpeed = nextLevel.speed - self.crafter.speed
			if nextLevelSpeed > 0 then
				upgradeInfo["Speed"] = nextLevelSpeed
			end
			self.cl.guiInterface:setData( "UpgradeInfo", upgradeInfo )
		else
			self.cl.guiInterface:setData( "UpgradeInfo", nil )
		end
	end
end

function Crafter.cl_n_onMessage( self, msg )
	sm.gui.displayAlertText( msg )
end

Workbench = class( Crafter )
Workbench.maxParentCount = 1
Workbench.connectionInput = sm.interactable.connectionType.logic

Dispenser = class( Crafter )
Dispenser.maxParentCount = 1
Dispenser.connectionInput = sm.interactable.connectionType.logic

Craftbot = class( Crafter )

Cookbot = class( Crafter )

--Raft
ScrapField = class( Crafter )
BigFarm = class( Crafter )
ScrapPurifier = class( Crafter )
ScrapTreeGrower = class( Crafter )
ScrapWorkbench = class( Crafter )
Apiary = class( Crafter )
SeedPress = class( Crafter )
Grill = class( Crafter )