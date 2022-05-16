dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_loot.lua"
dofile "$CONTENT_DATA/Scripts/game/raft_items.lua"

Rod = class()

local CONTENT_DATA = "$CONTENT_667b4c22-cc1a-4a2b-bee8-66a6c748d40e" --PLS FIX
local renderables = { CONTENT_DATA.."/Characters/Char_Tools/Char_fishingrod/char_char_fishingrod_preview.rend" }
local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local maxThrowForce = 5
local minThrowForce = 0.25
local chargeUpTime = 2
local hookSize = sm.vec3.one()*0.1

--SERVER Start
function Rod.server_onCreate( self )
	self.sv = {}
	self.sv.effects = {}
	self.sv.effects.hooks = {}

	self.hookIDs = 1
end

function Rod.sv_create_hook( self, params, player )
	local trigger = sm.areaTrigger.createBox(hookSize, params.pos)
	local bait = params.bait
	if not bait then
		bait = sm.uuid.new("4a971f7d-14e6-454d-bce8-0879243c7642") --SUS
	end

	self.sv.effects.hooks[#self.sv.effects.hooks + 1] = {pos = params.pos, dir = params.dir, trigger = hookSize, id = self.hookIDs}
	self.network:sendToClients("cl_create_hook", {pos = params.pos, dir = params.dir, bait = bait, id = self.hookIDs, player = player})
	self.hookIDs = self.hookIDs + 1
end

function Rod.server_onRefresh( self )
	self:server_onCreate()
end
--SERVER End



--CLIENT Start
function Rod.client_onCreate( self )
	self.chargeTime = 0
	self.bait = nil

	self.useCD = { active = false, timer = 1 }

	self.cl = {}
	self.cl.effects = {}
	self.cl.effects.hooks = {}
end

function Rod.cl_create_hook( self, params )
	local hookEffect = sm.effect.createEffect("ShapeRenderable")
	hookEffect:setParameter("uuid", params.bait)
	hookEffect:setParameter("color", sm.color.new(0,0,0))
	hookEffect:setScale(hookSize)
	hookEffect:start()

	ropeEffect = sm.effect.createEffect("ShapeRenderable")
	ropeEffect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	ropeEffect:setParameter("color", sm.color.new(1,1,1))
	ropeEffect:start()

	self.cl.effects.hooks[params.id] = {pos = params.pos, dir = params.dir, hook = hookEffect, rope = ropeEffect, player = params.player}
end


function Rod.cl_onPrimaryUse( self, state )
	print("ON PRIMARY USE")
end

function Rod.client_onEquippedUpdate( self, primaryState, secondaryState)
	--print(self.isThrowing)
	if self.chargeTime > 0 and not self.isThrowing then
		sm.gui.setProgressFraction(self.chargeTime/chargeUpTime)
	end
	self.primaryState = primaryState

	if primaryState ~= self.prevPrimaryState then
		if primaryState ~= 3 and not self.useCD.active then
			self:cl_reset()
			print("RESET")
		end
		self.prevPrimaryState = primaryState
	end

	if primaryState == 3 then
		self.isThrowing = true
		self.useCD.active = true

		local lookDir = sm.localPlayer.getDirection()
		local hookPos = self:calculateFirePosition(sm.localPlayer.getPlayer()) + lookDir / 2
		local hookDir = lookDir * math.max(self.chargeTime/chargeUpTime * maxThrowForce, minThrowForce)

		self.network:sendToServer("sv_create_hook", {pos = hookPos, dir = hookDir, bait = self.bait})
		sm.audio.play( "Sledgehammer - Swing" )
	end

	return true, true
end

function Rod:cl_should_stop_fishing()
	local owner = self.tool:getOwner()
	return self.useCD.active or owner.character:isSwimming() or owner.character:isDiving() or self.tool:isSprinting()
end

function Rod.client_onUpdate( self, dt )
	if self.useCD.active then
		self.useCD.timer = self.useCD.timer - dt
		if self.useCD.timer <= 0 then
			self.useCD = { active = false, timer = 1 }
		end
	end

	if self.tool:isEquipped() and self.primaryState == 1 or self.primaryState == 2 then
		self.chargeTime = math.min( self.chargeTime + dt, chargeUpTime)
	end

	if self:cl_should_stop_fishing() then
		self.chargeTime = 0
		if self.isFishing or self.isThrowing then
			self:cl_cancel()
		end
	end

	self:client_updateAnimations(dt)

	--self.cl.effects.hooks[params.id] = {pos = params.pos, dir = params.dir, hook = hookEffect, rope = ropeEffect, player = params.player}
	for id, effect in ipairs(self.cl.effects.hooks) do
		effect.pos = effect.pos + effect.dir*dt

		local delta = self:calculateFirePosition(effect.player) - effect.pos
		local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
		local scale = sm.vec3.new(0.01, 0.01, delta:length())

		effect.hook:setPosition(effect.pos)
		effect.hook:setRotation(rot)

		effect.rope:setPosition(effect.pos + delta * 0.5)
		effect.rope:setScale(scale)
		effect.rope:setRotation(rot)
	end
end

function Rod:client_onFixedUpdate( dt )
end

function Rod:cl_cancel()
	--check if catch here
	print("cancel")

	if self.isFishing or self.isThrowing then
		self.useCD.active = true
		sm.audio.play( "Sledgehammer - Swing" )
	end

	self:cl_reset()
end

function Rod:cl_reset()
	self.chargeTime = 0
	self.isThrowing = false
	self.isFishing = false
end

function Rod.calculateFirePosition( self, player )
	local character = player:getCharacter()

	local dir = character:getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.vec3.cross(dir, sm.vec3.new(0,0,1))
	right = right:normalize()

	local fireOffset = sm.vec3.new( 1.0, 0.0, 0.75 )

	fireOffset = dir
	fireOffset.z = 0.0
	fireOffset = fireOffset:normalize()*1.2
	fireOffset.z = fireOffset.z + 1

	fireOffset = fireOffset + right * 0.25
	fireOffset = fireOffset:rotate( math.rad( pitch ), right )

	local firePosition = character:getWorldPosition() + fireOffset
	return firePosition
end

function Rod.client_onUnequip( self, animate )
	self:cl_reset()

	self:client_UnequipAnimation(animate)
end

function Rod.client_onRefresh( self )
	self:client_onCreate()

	self:loadAnimations()
end
--CLIENT END















--Animations START
function Rod.loadAnimations( self )
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

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spudgun_pickup", { nextAnimation = "idle" } },
				unequip = { "spudgun_putdown" },
				idle = { "spudgun_idle", { looping = true } },

				sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "spudgun_sprint_idle", { looping = true } },
			}
		)
	end

	self.blendTime = 0.2
	self.spineWeight = 0.0
	self.jointWeight = 0.0
end

function Rod.client_updateAnimations( self, dt )
	-- First person animation
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()

	if self.tool:isLocal() then
		if self.equipped then
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

	local playerDir = self.tool:getDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
	local linareAngle = playerDir:dot( sm.vec3.new( 0, 0, 1 ) )

	local linareAngleDown = clamp( -linareAngle, 0.0, 1.0 )

	down = clamp( -angle, 0.0, 1.0 )
	fwd = ( 1.0 - math.abs( angle ) )
	up = clamp( angle, 0.0, 1.0 )

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if name == "pickup" then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 0.001 )
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

	-- Third Person joint lock
	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	self.jointWeight = math.max( self.jointWeight - ( 6.0 * dt ), 0.0 )

	if ( not isSprinting ) then
		self.spineWeight = math.min( self.spineWeight + ( 10.0 * dt ), 1.0 )
	else
		self.spineWeight = math.max( self.spineWeight - ( 10.0 * dt ), 0.0 )
	end

	local finalAngle = ( 0.5 + angle * 0.5 )
	self.tool:updateAnimation( "spudgun_spine_bend", finalAngle, self.spineWeight )

	local totalOffsetZ = lerp( -22.0, -26.0, crouchWeight )
	local totalOffsetY = lerp( 6.0, 12.0, crouchWeight )
	local crouchTotalOffsetX = clamp( ( angle * 60.0 ) -15.0, -60.0, 40.0 )
	local normalTotalOffsetX = clamp( ( angle * 50.0 ), -45.0, 50.0 )
	local totalOffsetX = lerp( normalTotalOffsetX, crouchTotalOffsetX , crouchWeight )
	local finalJointWeight = ( self.jointWeight )

	self.tool:updateJoint( "jnt_hips", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.35 * finalJointWeight * ( normalWeight ) )

	local crouchSpineWeight = ( 0.35 / 3 ) * crouchWeight

	self.tool:updateJoint( "jnt_spine1", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight )  * finalJointWeight )
	self.tool:updateJoint( "jnt_spine2", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_spine3", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.45 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_head", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.3 * finalJointWeight )
end

function Rod.client_onEquip( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	currentRenderablesTp = {}
	currentRenderablesFp = {}

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.tool:setTpRenderables( currentRenderablesTp )
	self:loadAnimations()
	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		-- Sets Rod renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Rod.client_UnequipAnimation( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end
end

--Animations END