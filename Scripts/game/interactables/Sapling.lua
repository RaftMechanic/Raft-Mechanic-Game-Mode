dofile("$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua")

dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua")

Sapling = class()
--hvs_burntforest.json
Sapling.burned = {
	sm.uuid.new("9ef210c0-ea30-4442-a1fe-924b5609b0cc"),
	sm.uuid.new("2bae67d4-c8ef-4c6e-a1a7-42281d0b7489"),
	sm.uuid.new("8f7a8108-2712-47b3-bce2-f25315165094"),
	sm.uuid.new("515aed88-0594-42b6-a352-617e5f5a3e45"),
	sm.uuid.new("2d5aa53d-eb9c-478c-a70f-c57a43753814"),
	sm.uuid.new("c08b553a-a917-4e26-bbb6-7b8523789cad"),
	sm.uuid.new("d3fcfc06-a6b6-4598-99b1-9a6445b976b3"),
	sm.uuid.new("b5f90719-fbca-4c59-89c3-187cdb5553d4")
}

function Sapling.server_onCreate(self)
	self.sv = {}
	self.sv.boundingBox = nil
	self.sv.caculatingBox = true

	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.grow = -1
		self.sv.saved.burned = false
		self.sv.saved.planted = false
		self.sv.saved.valid = false
	end

	self:server_clientDataUpdate()
end

function Sapling.client_onCreate(self)
	self.cl = {}
	self.cl.caculating = true -- default true!
	self.cl.valid = false
	self.cl.planted = false
end

function Sapling.sv_checkGround(self)
	local valid = false
	local treePos = sm.vec3.zero()
	local raycast_start = self.shape.worldPosition + sm.vec3.new(0,0,0.125)
	local raycast_end = self.shape.worldPosition + sm.vec3.new(0,0,-0.3)
	local body = sm.shape.getBody(self.shape)
	local success, result = sm.physics.raycast( raycast_start, raycast_end, body)

	local trigger = sm.areaTrigger.createAttachedBox( self.interactable, sm.vec3.one() / 4, sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.areaTrigger )

	local isInWater = false
	if sm.exists(trigger) then
		for _, content in ipairs( trigger:getContents() ) do
			if sm.exists( content ) then
				local userData = content:getUserData()
				if userData and userData.water then
					isInWater = true
				end
			end
		end
	end

	sm.areaTrigger.destroy(trigger)

	if success and result.type == "terrainSurface" and not isInWater then
		valid = true
		treePos = result.pointWorld
	end
	return valid, treePos
end

function Sapling.server_clientDataUpdate( self )
	self.network:setClientData( { valid = self.sv.saved.valid or false, planted = self.sv.saved.planted or false, caculating = self.sv.caculatingBox } )
end

function Sapling.client_onClientDataUpdate( self, params )
	self.cl.caculating = params.caculating
	self.cl.valid = params.valid
	self.cl.planted = params.planted
end

function Sapling.client_canInteract(self)
	local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"

	if self.cl.planted then
		sm.gui.setInteractionText("", o1..language_tag("SaplingGrow")..o2, "")
	elseif self.cl.valid then
		sm.gui.setInteractionText(o1..language_tag("SaplingNeedLiquid")..o2)
	elseif not self.cl.caculating then
		sm.gui.setInteractionText(o1..language_tag("SaplingNeedGround")..o2)
	end
	return true
end

function Sapling.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	local chemical = projectileName == "chemical"

	if projectileName == "water" or chemical and not self.sv.planted then
		local valid, treePos = Sapling.sv_checkGround(self)

		if valid then
			sm.effect.playEffect("Cotton - Picked", treePos + sm.vec3.new(0, 0, -0.5))
			sm.effect.playEffect("Tree - LogAppear", treePos)

			self.sv.saved.treePos = treePos
			self.sv.saved.grow = math.random(60, 60*24) --1 to 24 minutes
			self.sv.saved.planted = true
			self.sv.saved.burned = chemical
			self.storage:save( self.sv.saved )
			self.network:setClientData( { valid = self.sv.saved.valid, planted = self.sv.saved.planted } )

			if chemical then
				sm.effect.playEffect("Plants - Destroyed", self.shape.worldPosition)
			else
				sm.effect.playEffect("Plants - Planted", self.shape.worldPosition)
			end
		end
	end
end

function Sapling:server_onFixedUpdate()
	if self.sv.saved and self.sv.saved.planted and sm.game.getCurrentTick() % (40 * 5) == 0 then
		if self.sv.saved.grow == 0 then
			local offset = sm.vec3.new(0.375, -0.375, 0)
			if self.sv.saved.burned then --chemicals lead to ember trees
				self.trees = self.burned
			end
			sm.harvestable.create( self.trees[math.random(#self.trees)], self.sv.saved.treePos - offset, sm.quat.new(0.707, 0, 0, 0.707) )
			self.shape:destroyPart(0)
			return
		end
		self.sv.saved.grow = math.max(self.sv.saved.grow - 5, 0) -- five seconds per call
		self.storage:save( self.sv.saved )
	end

	if self.sv.caculatingBox and sm.game.getCurrentTick() % 6 == 0 then
		self.sv.saved.grow = -1
		self.sv.saved.valid, self.sv.saved.treePos = Sapling.sv_checkGround(self)

		self.storage:save( self.sv.saved )
		self.network:setClientData( { valid = self.sv.saved.valid, planted = self.sv.saved.planted } )

		self.sv.caculatingBox = false
	end
end

function Sapling:server_canErase()
	return not self.sv.saved.planted
end

function Sapling:client_canErase()
	if self.cl.planted then
		sm.gui.displayAlertText(language_tag("SaplingCantErase"), 2.5)
	end

	return not self.cl.planted
end

BirchSapling = class( Sapling )
BirchSapling.trees = { hvs_tree_birch01, hvs_tree_birch01, hvs_tree_birch03 }

LeafySapling = class( Sapling )
LeafySapling.trees = { hvs_tree_leafy01, hvs_tree_leafy02, hvs_tree_leafy03}

SpruceSapling = class( Sapling )
SpruceSapling.trees = { hvs_tree_spruce01, hvs_tree_spruce02, hvs_tree_spruce03 }

PineSapling = class( Sapling )
PineSapling.trees = { hvs_tree_pine01, hvs_tree_pine02, hvs_tree_pine03 }