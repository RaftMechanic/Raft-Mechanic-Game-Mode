
dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

TorchTool = class()

local renderables = {
	[tostring(obj_torch)] = "$CONTENT_DATA/Characters/Char_Tools/Char_torch/char_torch.rend",
	[tostring(obj_torch_lit)] = "$CONTENT_DATA/Characters/Char_Tools/Char_torch/char_torch_lit.rend",
	[tostring(obj_torch_burnt)] = "$CONTENT_DATA/Characters/Char_Tools/Char_torch/char_torch_burnt.rend"
}
local torches = {
	obj_torch,
	obj_torch_lit,
	obj_torch_burnt
}
local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )


function TorchTool.client_onCreate( self )
	self:cl_init()
end

function TorchTool.client_onRefresh( self )
	self:cl_init()
end

function TorchTool.cl_init( self )
	self:cl_loadAnimations()

	self.cl = {}
	self.cl.effect = sm.effect.createEffect( "Fire - small01", self.tool:getOwner().character, "jnt_fertilizer" )
	self.cl.effect:setOffsetPosition(sm.vec3.new(0, 0.35, -0.35))
	self.cl.equippedItem = sm.uuid.getNil()
	self.renderable = nil

	if self.tool:isLocal() then
		self.cl.lit = false
	end
end

function TorchTool.cl_loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "fertilizer_idle", { looping = true } },
			use = { "fertilizer_paint", { nextAnimation = "idle" } },
			sprint = { "fertilizer_sprint" },
			pickup = { "fertilizer_pickup", { nextAnimation = "idle" } },
			putdown = { "fertilizer_putdown" }

		}
	)
	local movementAnimations = {

		idle = "fertilizer_idle",
		idleRelaxed = "fertilizer_idle_relaxed",

		runFwd = "fertilizer_run_fwd",
		runBwd = "fertilizer_run_bwd",
		sprint = "fertilizer_sprint",

		jump = "fertilizer_jump",
		jumpUp = "fertilizer_jump_up",
		jumpDown = "fertilizer_jump_down",

		land = "fertilizer_jump_land",
		landFwd = "fertilizer_jump_land_fwd",
		landBwd = "fertilizer_jump_land_bwd",

		crouchIdle = "fertilizer_crouch_idle",
		crouchFwd = "fertilizer_crouch_fwd",
		crouchBwd = "fertilizer_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "fertilizer_idle", { looping = true } },

				sprintInto = { "fertilizer_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintIdle = { "fertilizer_sprint_idle", { looping = true } },
				sprintExit = { "fertilizer_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

				use = { "fertilizer_paint", { nextAnimation = "idle" } },

				equip = { "fertilizer_pickup", { nextAnimation = "idle" } },
				unequip = { "fertilizer_putdown" }
			}
		)
	end
	setTpAnimation( self.tpAnimations, "idle", 5.0 )
	self.blendTime = 0.2
end

function TorchTool.client_onUpdate( self, dt )

	-- First person animation
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()

	if self.tool:isLocal() then
		if self.equipped then
			local item = sm.localPlayer.getActiveItem()
			if item ~= self.cl.equippedItem and isAnyOf(item, torches) then
				self.cl.lit = item == obj_torch_lit

				self.network:sendToServer("sv_updateFire", item == obj_torch_lit)
				self.network:sendToServer("sv_equip", item)
			end

			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if animation.time >= animation.info.duration - self.blendTime and not animation.looping then
				if ( name == "use" ) then
					setTpAnimation( self.tpAnimations, "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end

			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do

		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end
end

function TorchTool.client_onEquip( self )
	if self.tool:isLocal() then
		local item = sm.localPlayer.getActiveItem()
		self.network:sendToServer("sv_equip", item)
	end
end

function TorchTool:sv_equip( item )
	if item == obj_torch_lit then
		self:sv_updateFire(true)
	end

	self.network:sendToClients("cl_equip", item)
end

function TorchTool:cl_equip( item )
	self.wantEquipped = true
	self.cl.equippedItem = item

	self:cl_updateRenderables( item, false )

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.tool:isLocal() then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function TorchTool:cl_updateRenderables( item, loadAnim )
	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	self.renderable = { renderables[tostring(item)] }

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( self.renderable ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( self.renderable ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
	end
	self.tool:setTpRenderables( currentRenderablesTp )

	self:cl_loadAnimations()

	if loadAnim == nil then
		setTpAnimation( self.tpAnimations, "idle", 0.0001 )
		if self.tool:isLocal() then
			setFpAnimation( self.fpAnimations, "idle", 0.0001 )
		end
	end
end

function TorchTool.client_onUnequip( self )
	self.cl.equippedItem = sm.uuid.getNil()
	self.wantEquipped = false
	self.equipped = false
	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() then
			if self.cl.lit then
				self.cl.lit = false
				self.network:sendToServer("sv_updateFire", false)
			end

			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
			end
		end
	end
end

function TorchTool.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuild )
	local char = self.tool:getOwner().character
 	if not sm.exists(char) then return end

	local valid, worldPos, worldNormal = ConstructionRayCast( { "terrainSurface", "terrainAsset", "body", "joint" } )
	if valid then
		local keyBindingText =  sm.gui.getKeyBinding( "ForceBuild", true )
		sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_FORCE_BUILD}" )
	end

	local prevLit = self.cl.lit

	if primaryState == sm.tool.interactState.start then
		self.cl.lit = forceBuild == false and not self.cl.lit or false
	end

	if char:isSwimming() or char:isDiving() then
		self.cl.lit = false
	end

	if prevLit ~= self.cl.lit then
		self.network:sendToServer("sv_updateFire", self.cl.lit)
	end

	return not forceBuild, false
end

function TorchTool:sv_updateFire( toggle )
	local item = toggle and obj_torch_lit or obj_torch_burnt
	self.network:sendToClients("cl_updateFire", { toggle = toggle, item = item })
end

function TorchTool:cl_updateFire( args )
	if args.toggle then
		self.cl.effect:start()
	else
		self.cl.effect:stop()
	end

	self:cl_updateRenderables( args.item )
end