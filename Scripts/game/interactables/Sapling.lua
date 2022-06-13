--to any pour soul who might stumble upon this script
--please close it as soon as possible
--fuck areatrigger bullshit

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

	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.grow = -1
		self.sv.saved.burned = false
		self.sv.saved.planted = false
		self.sv.saved.valid = false
	end

	self.sv.tries = 0
	self.sv.waterTrigger = sm.areaTrigger.createAttachedBox( self.interactable, sm.vec3.one() / 4, sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.areaTrigger )
	self.network:setClientData( { valid = self.sv.saved.valid, planted = self.sv.saved.planted } )
end

function Sapling.sv_checkGround(self)
	for _, content in ipairs( self.sv.waterTrigger:getContents() ) do
		if sm.exists( content ) then
			local userData = content:getUserData()
			if userData and userData.water then
				self.sv.saved.valid = false
				self.sv.saved.treePos = nil
				self.network:setClientData( { valid = self.sv.saved.valid, planted = self.sv.saved.planted } )
				return
			end
		end
	end

	local success, result = sm.physics.raycast( self.shape.worldPosition + sm.vec3.new(0,0,0.5), self.shape.worldPosition + sm.vec3.new(0,0,-0.5), self.shape.body )
	self.sv.saved.valid = success and result.type == "terrainSurface"
	self.sv.saved.treePos = result.pointWorld
	self.network:setClientData( { valid = self.sv.saved.valid, planted = self.sv.saved.planted } )
end

function Sapling.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if not self.sv.saved.valid or self.sv.saved.treePos == nil then return end

	local chemical = projectileName == "chemical"

	if projectileName == "water" or chemical and not self.sv.planted then
		sm.effect.playEffect("Cotton - Picked", self.sv.saved.treePos + sm.vec3.new(0, 0, -0.5))
		sm.effect.playEffect("Tree - LogAppear", self.sv.saved.treePos)

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

function Sapling:server_onFixedUpdate()
	if not self.sv.saved or not sm.exists(self.sv.waterTrigger) then return end

	local tick = sm.game.getCurrentTick()
	if not self.sv.saved.valid or self.sv.tries < 10 then
		if tick % 10 == 0 then
			self:sv_checkGround()
			self.sv.tries = self.sv.tries + 1
		end

		return
	end

	if self.sv.saved.planted and tick % (40 * 5) == 0 then
		if self.sv.saved.grow == 0 then
			local offset = sm.vec3.new(0.375, -0.375, 0)
			if self.sv.saved.burned then
				self.trees = self.burned
			end

			sm.harvestable.create( self.trees[math.random(#self.trees)], self.sv.saved.treePos - offset, sm.quat.new(0.707, 0, 0, 0.707) )
			self.shape:destroyPart(0)
			return
		end

		self.sv.saved.grow = math.max(self.sv.saved.grow - 5, 0)
		self.storage:save( self.sv.saved )
	end
end

function Sapling:server_canErase()
	return not self.sv.saved.planted
end



function Sapling.client_onCreate(self)
	self.cl = {}
	self.cl.valid = false
	self.cl.planted = false
end

function Sapling.client_onClientDataUpdate( self, params )
	self.cl.valid = params.valid
	self.cl.planted = params.planted
end

function Sapling.client_canInteract(self)
	local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"

	if self.cl.planted then
		sm.gui.setInteractionText(o1..language_tag("SaplingGrow")..o2)
		return false
	end

	if self.cl.valid then
		sm.gui.setInteractionText(o1..language_tag("SaplingNeedLiquid")..o2)
	else
		sm.gui.setInteractionText(o1..language_tag("SaplingNeedGround")..o2)
	end

	return false
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