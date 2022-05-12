dofile("$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua")

dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua")

Sapling = class()
--hvs_burntforest.json
Sapling.burned = {	sm.uuid.new("9ef210c0-ea30-4442-a1fe-924b5609b0cc"),
					sm.uuid.new("2bae67d4-c8ef-4c6e-a1a7-42281d0b7489"),
					sm.uuid.new("8f7a8108-2712-47b3-bce2-f25315165094"),
					sm.uuid.new("515aed88-0594-42b6-a352-617e5f5a3e45"),
					sm.uuid.new("2d5aa53d-eb9c-478c-a70f-c57a43753814"),
					sm.uuid.new("c08b553a-a917-4e26-bbb6-7b8523789cad"),
					sm.uuid.new("d3fcfc06-a6b6-4598-99b1-9a6445b976b3"),
					sm.uuid.new("b5f90719-fbca-4c59-89c3-187cdb5553d4")	}

function Sapling.server_onCreate(self)
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
		self.caculatingBox = true
		self.saved.burned = false
	end

	self:server_clientDataUpdate()
end

function Sapling.client_onCreate(self)
	self.caculating = true -- default true!
end

function Sapling.check_ground(self)
	local valid = false
	local treePos = sm.vec3.zero()
	local raycast_start = self.shape.worldPosition + sm.vec3.new(0,0,0.125)
	local raycast_end = self.shape.worldPosition + sm.vec3.new(0,0,-0.3)
	local body = sm.shape.getBody(self.shape)
	local success, result = sm.physics.raycast( raycast_start, raycast_end, body)
	
	local isInWater = false
	if sm.exists(self.boundingBox) then
		for _, result in ipairs( self.boundingBox:getContents() ) do
			if sm.exists( result ) then
				local userData = result:getUserData()
				if userData and userData.water then
					isInWater = true
				end
			end
		end
	end

	if success and result.type == "terrainSurface" and not isInWater  then
		valid = true
		treePos = result.pointWorld
	end
	return valid, treePos
end

function Sapling.server_clientDataUpdate( self )
	self.network:setClientData( { valid = self.saved.valid or false, planted = self.saved.planted or false, caculating = self.caculatingBox } )
end

function Sapling.client_onClientDataUpdate( self, params )
	self.caculating = params.caculating
	self.valid = params.valid
	self.planted = params.planted
end

function Sapling.client_canInteract(self)
	if self.planted then
		sm.gui.setInteractionText("", language_tag("SaplingGrow"), "")
	elseif self.valid then
		sm.gui.setInteractionText(language_tag("SaplingNeedLiquid1"), language_tag("SaplingNeedLiquid2"), "")
	elseif not self.caculating then
		sm.gui.setInteractionText(language_tag("SaplingNeedGround1"), "#ff0000" .. language_tag("SaplingNeedGround2"), "")
	end
	return true
end

function Sapling.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	
	local chemical = projectileName == "chemical"

	if projectileName == "water" or chemical and not self.planted then
		local valid, treePos = Sapling.check_ground(self)

		if valid then		
			sm.effect.playEffect("Cotton - Picked", treePos + sm.vec3.new(0, 0, -0.5))
			sm.effect.playEffect("Tree - LogAppear", treePos)
			
			self.saved.treePos = treePos
			self.saved.grow = math.random(60, 60*24) --1 to 24 minutes
			
			self.saved.planted = true
			self.saved.burned = chemical
			self.storage:save( self.saved )
			self.network:setClientData( { valid = self.saved.valid, planted = self.saved.planted } )
			
			-- destroy bounding box
			if sm.exists(self.boundingBox) then
				sm.areaTrigger.destroy( self.boundingBox )
			end

			if chemical then
				sm.effect.playEffect("Plants - Destroyed", self.shape.worldPosition)
			else
				sm.effect.playEffect("Plants - Planted", self.shape.worldPosition)
			end
		end
	end
end

function Sapling:server_onFixedUpdate()
	if self.saved and self.planted and sm.game.getCurrentTick() % (40 * 5) == 0 then
		if self.saved.grow == 0 then
			local offset = sm.vec3.new(0.375, -0.375, 0)
			if self.saved.burned then --chemicals lead to ember trees
				self.trees = self.burned
			end
			sm.harvestable.create( self.trees[math.random(#self.trees)], self.saved.treePos - offset, sm.quat.new(0.707, 0, 0, 0.707) )
			self.shape:destroyPart(0)
			return
		end
		self.saved.grow = math.max(self.saved.grow - 5, 0) -- five seconds per call
		self.storage:save( self.saved )
	end

	if self.caculatingBox and sm.game.getCurrentTick() % 6 == 0 then 
		if self.boundingBox == nil then
			self.boundingBox = sm.areaTrigger.createAttachedBox( self.interactable, sm.vec3.one() / 4, sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.areaTrigger )
			return -- return so box can caculate its contents.
		end

		self.saved.grow = -1
		self.saved.valid, self.saved.treePos = Sapling.check_ground(self)

		self.storage:save( self.saved )
		self.network:setClientData( { valid = self.saved.valid, planted = self.saved.planted } )

		self.caculatingBox = false
	end	
end

function Sapling:server_canErase()
	return not self.planted
end

BirchSapling = class( Sapling )
BirchSapling.trees = { hvs_tree_birch01, hvs_tree_birch01, hvs_tree_birch03 }

LeafySapling = class( Sapling )
LeafySapling.trees = { hvs_tree_leafy01, hvs_tree_leafy02, hvs_tree_leafy03}

SpruceSapling = class( Sapling )
SpruceSapling.tree = { hvs_tree_spruce01, hvs_tree_spruce02, hvs_tree_spruce03 }

PineSapling = class( Sapling )
PineSapling.tree = { hvs_tree_pine01, hvs_tree_pine02, hvs_tree_pine03 }