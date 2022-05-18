dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

Hook = class()

local renderables = {
	"$CONTENT_DATA/Characters/Char_Tools/Char_pullinghook/char_pullinghook_preview.rend"
}

local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

--raft
local actualDt = 0

local function vec3Num( num )
	return sm.vec3.new(num,num,num)
end

local collectables = {
	blk_scrapwood,
	blk_plastic,
	obj_consumable_gas,
	obj_consumable_water,
	obj_consumable_fertilizer,
	obj_consumable_sunshake
}

local hookSize = vec3Num(0.35)
local colllectHookRange = 0.75
local maxThrowForce = 15
local minThrowForce = 5
local chargeUpTime = 1.75
local ThrowSpeed = 4.5
local PullSpeed = 2
local maxPullMultiplier = 5

function Hook:server_onCreate()
	self.sv = {}
	self.sv.hooks = {}
	self.sv.pullForces = {}
end

function Hook.client_onCreate( self )
	self.cl = {}
	self.cl.player = sm.localPlayer.getPlayer()
	self.cl.playerId = self.cl.player:getId()
	self.cl.firePoss = {}
	self.cl.effects = {}

	self.cl.throwForce = 0
	self.cl.isReversing = false
	self.cl.primaryState = 0
	self.cl.secondaryState = 0
	self.cl.pullMultiplier = 0

	self.network:sendToServer("sv_setPullForceForClient", { index = self.cl.playerId, force = self.cl.pullMultiplier })
	--raft
end

function Hook.client_onRefresh( self )
	self:loadAnimations()
end

function Hook.loadAnimations( self )
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "spudgun_idle" },
			pickup = { "spudgun_pickup", { nextAnimation = "idle" } },
			putdown = { "spudgun_putdown" }
		}
	)
	local movementAnimations = {
		idle = "spudgun_idle",
		idleRelaxed = "spudgun_relax",

		sprint = "spudgun_sprint",
		runFwd = "spudgun_run_fwd",
		runBwd = "spudgun_run_bwd",

		jump = "spudgun_jump",
		jumpUp = "spudgun_jump_up",
		jumpDown = "spudgun_jump_down",

		land = "spudgun_jump_land",
		landFwd = "spudgun_jump_land_fwd",
		landBwd = "spudgun_jump_land_bwd",

		crouchIdle = "spudgun_crouch_idle",
		crouchFwd = "spudgun_crouch_fwd",
		crouchBwd = "spudgun_crouch_bwd"
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
				shoot = { "spudgun_shoot", { nextAnimation = "idle" } },

				sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "spudgun_sprint_idle", { looping = true } },
			}
		)
	end

	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3

	self.aimBlendSpeed = 3.0
	self.blendTime = 0.2

	self.jointWeight = 0.0
	self.spineWeight = 0.0
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )

end

--raft
function Hook:sv_setPullForceForClient( args )
	self.sv.pullForces[args.index] = args.force
end

function Hook:sv_setFirePoss( args )
	self.network:sendToClients("cl_setFirePoss", args)
end

function Hook:cl_setFirePoss( args )
	self.cl.firePoss[args.index] = args.data
end

function Hook:sv_throwHook( args )
	local hook = {
		owner = args.owner,
		speed = sm.vec3.one(),
		waterTrigger = nil,
		shapeTrigger = nil,
		isThrowing = true,
		isReversing = false,
		pos = args.pos,
		dir = args.dir,
		throwForce = args.throwForce
	}

	hook.waterTrigger = sm.areaTrigger.createBox( hookSize * 2, args.pos, sm.quat.identity(), sm.areaTrigger.filter.areaTrigger )
	hook.shapeTrigger = sm.areaTrigger.createBox( hookSize * 12, args.pos, sm.quat.identity(), sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.staticBody )

	local ownerId = args.owner:getId()
	self.sv.hooks[ownerId] = hook
	self.network:sendToClients("cl_throwHook", { pos = args.pos, dir = args.dir, index = ownerId })
end

function Hook:cl_throwHook( args )
	local hook = {}
	hook.rope = sm.effect.createEffect("ShapeRenderable")
	hook.rope:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	hook.rope:setParameter("color", sm.color.new(0,0,0))

	--local firePosTable = firePoss[args.index]
	--local firePos = sm.localPlayer.isInFirstPersonView() and self.cl.playerId == args.index and firePosTable.fp or firePosTable.tp
	hook.rope:setPosition( args.pos ) --firePos )

	hook.rope:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), args.dir ) )
	hook.rope:setScale(hookSize)
	hook.rope:start()

	hook.hook = sm.effect.createEffect("ShapeRenderable")
	hook.hook:setParameter("uuid", sm.uuid.new("4a971f7d-14e6-454d-bce8-0879243c8735"))
	hook.hook:setParameter("color", sm.color.new(1,0,0))
	hook.hook:setPosition( args.pos )
	hook.hook:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), args.dir ) )
	hook.hook:setScale(hookSize)
	hook.hook:start()

	self.cl.effects[args.index] = hook
end

function Hook:sv_applyImpulse( args )
	local dir = args.dir
	local distance = args.owner:getCharacter():getWorldPosition() - args.body:getWorldPosition()
	local mult = 1 + self.sv.pullForces[args.owner:getId()]

	if args.body:getVelocity():length() < PullSpeed * 3 * math.max(distance:length()/10, 1) * mult then
		sm.physics.applyImpulse( args.body, dir * args.body:getMass() * (actualDt / 2.5) * math.max(distance:length()/20, 1) * mult, true )
	end
end

function Hook:cl_calculateHookEffectData( args )
	for v, k in pairs(args) do
		if self.cl.effects[k.index] ~= nil and self.cl.firePoss[k.index] ~= nil then
			local firePosTable = self.cl.firePoss[k.index]
			local firePos = self.cl.playerId == k.index and sm.localPlayer.isInFirstPersonView() and firePosTable.fp or firePosTable.tp

			local delta = firePos - k.pos
			local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
			local distance = sm.vec3.new(0.01, 0.01, delta:length())

			self.cl.effects[k.index].rope:setPosition(k.pos + delta * 0.5)
			self.cl.effects[k.index].rope:setScale(distance)
			self.cl.effects[k.index].rope:setRotation(rot)

			self.cl.effects[k.index].hook:setPosition(k.pos)
			self.cl.effects[k.index].hook:setRotation(rot)

			if self.cl.playerId == k.index then
				self.cl.isReversing = k.isReversing
			end
		end
	end
end

function Hook:sv_reset( ownerId )
	self.sv.hooks[ownerId] = nil
	self.network:sendToClients("cl_reset", ownerId)
end

function Hook:cl_reset( ownerId )
	if self.cl.effects[ownerId] == nil then return end

	self.cl.effects[ownerId].rope:stop()
	self.cl.effects[ownerId].hook:stop()
	self.cl.effects[ownerId] = nil

	if ownerId == self.cl.playerId then
		self.cl.isReversing = false
	end
end

function Hook:client_onFixedUpdate( dt )
	self.cl.player = sm.localPlayer.getPlayer()
	self.cl.playerId = sm.localPlayer.getPlayer():getId()
	local prevPullForce = self.cl.pullMultiplier

	if self.tool:isEquipped() and (self.cl.primaryState == 1 or self.cl.primaryState == 2) then
		self.cl.throwForce = math.min(self.cl.throwForce + dt/chargeUpTime * maxThrowForce, maxThrowForce)
	end

	if self.tool:isEquipped() and (self.cl.secondaryState == 1 or self.cl.secondaryState == 2) and self.cl.isReversing then
		self.cl.pullMultiplier = math.min(self.cl.pullMultiplier + dt/chargeUpTime * maxPullMultiplier, maxPullMultiplier)
	else
		self.cl.pullMultiplier = 0
	end

	if prevPullForce ~= self.cl.pullMultiplier then
		self.network:sendToServer("sv_setPullForceForClient", { index = self.cl.playerId, force = self.cl.pullMultiplier })
	end

	self.network:sendToServer("sv_setFirePoss", { index = self.cl.playerId, data = { fp = self:calculateFirePosition(), tp = self:calculateTpMuzzlePos() } })
end

function Hook:server_onFixedUpdate( dt )
	local hookData = {}

	for v, hook in pairs(self.sv.hooks) do
		if sm.exists(hook.waterTrigger) and sm.exists(hook.shapeTrigger) then
			local ownerId = hook.owner:getId()

			if hook.isThrowing then
				hook.dir = hook.dir - sm.vec3.new(0,0,0.05 / hook.throwForce)
				hook.pos = hook.pos + vec3Num(hook.throwForce) * ThrowSpeed * hook.dir * actualDt

				hook.waterTrigger:setWorldPosition( hook.pos )
				hook.shapeTrigger:setWorldPosition( hook.pos )

				local hitWater = false
				if sm.exists(hook.waterTrigger) then
					for _, result in ipairs( hook.waterTrigger:getContents() ) do
						if sm.exists( result ) then
							local userData = result:getUserData()
							if userData then
								hitWater = true
							end
						end
					end
				end

				local hit, result = sm.physics.raycast( hook.pos, hook.pos + hook.dir * hook.throwForce * (actualDt*2) )

				if hitWater then
					hook.isThrowing = false
					hook.isReversing = true
					hook.throwForce = 0
				elseif not hitWater and hit then
					if not result:getShape() or not isAnyOf(result:getShape():getShapeUuid(), collectables) then
						self:sv_reset( ownerId )
					end
				end
			end

			if hook.isReversing then
				local playerChar = hook.owner:getCharacter()
				local playerPos = playerChar:getWorldPosition()
				local dir = playerPos - hook.pos

				local distance = sm.vec3.new(playerPos.x, playerPos.y, 0) - sm.vec3.new(hook.pos.x, hook.pos.y, 0)
				hook.dir = sm.vec3.new(dir.x, dir.y, 0)
				hook.pos = hook.pos + sm.vec3.one() / 4 * hook.dir * PullSpeed * (1 + self.sv.pullForces[ownerId]) * actualDt

				hook.waterTrigger:setWorldPosition( hook.pos )
				hook.shapeTrigger:setWorldPosition( hook.pos )

				for _, body in ipairs( hook.shapeTrigger:getContents() ) do
					if sm.exists( body ) then
						if body:getMass() < 100 then
							self:sv_applyImpulse( { body = body, owner = hook.owner, dir = hook.dir } )
						end
					end
				end

				if distance:length() <= colllectHookRange then
					sm.areaTrigger.destroy(hook.waterTrigger)
					sm.areaTrigger.destroy(hook.shapeTrigger)
					self:sv_reset( ownerId )
				end
			end

			hookData[#hookData+1] = { pos = hook.pos, index = ownerId, isReversing = hook.isReversing }
		end
	end

	if #hookData == 0 then return end
	self.network:sendToClients("cl_calculateHookEffectData", hookData )
end

function Hook.client_onUpdate( self, dt )
	--raft
	--dt in onFixed is always 0.025 even if your framerate is below 40
	--fucking hell
	if sm.isHost then
		actualDt = dt
	end
	--raft

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

			if self.aiming and not isAnyOf( self.fpAnimations.currentAnimation, { "aimInto", "aimIdle", "aimShoot" } ) then
				swapFpAnimation( self.fpAnimations, "aimExit", "aimInto", 0.0 )
			end
			if not self.aiming and isAnyOf( self.fpAnimations.currentAnimation, { "aimInto", "aimIdle", "aimShoot" } ) then
				swapFpAnimation( self.fpAnimations, "aimInto", "aimExit", 0.0 )
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

	-- Timers
	self.sprintCooldownTimer = math.max( self.sprintCooldownTimer - dt, 0.0 )

	-- Sprint block
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint( blockSprint )

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
				if ( name == "shoot" or name == "aimShoot" ) then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 10.0 )
				elseif name == "pickup" then
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
	if ( ( ( isAnyOf( self.tpAnimations.currentAnimation, { "aimInto", "aim", "shoot" } ) and ( relativeMoveDirection:length() > 0 or isCrouching) ) or ( self.aiming and ( relativeMoveDirection:length() > 0 or isCrouching) ) ) and not isSprinting ) then
		self.jointWeight = math.min( self.jointWeight + ( 10.0 * dt ), 1.0 )
	else
		self.jointWeight = math.max( self.jointWeight - ( 6.0 * dt ), 0.0 )
	end

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


	-- Camera update
	local bobbing = 1
	if self.aiming then
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, dt * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 1.0, blend )
		bobbing = 0.12
	else
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, dt * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 0.0, blend )
		bobbing = 1
	end

	self.tool:updateCamera( 2.8, 30.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
	self.tool:updateFpCamera( 30.0, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, bobbing )
end

function Hook.client_onEquip( self, animate )

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	self.aiming = false
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
		-- Sets Hook renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Hook.client_onUnequip( self, animate )
	--raft
	self.network:sendToServer("sv_reset", self.cl.playerId)
	--raft

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

function Hook.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function Hook.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function Hook.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function Hook.sv_n_onShoot( self, dir )
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function Hook.cl_n_onShoot( self, dir )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function Hook.onShoot( self, dir )

	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
			self.shootEffectFP:start()
		else
			self.shootEffect:start()
	end

end

function Hook.calculateFirePosition( self )
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	if crouching then
		fireOffset.z = 0.15
	else
		fireOffset.z = 0.45
	end

	if firstPerson then
		if not self.aiming then
			fireOffset = fireOffset + right * 0.05
		end
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate( math.rad( pitch ), right )
	end
	local firePosition = GetOwnerPosition( self.tool ) + fireOffset
	return firePosition
end

function Hook.calculateTpMuzzlePos( self )
	local crouching = self.tool:isCrouching()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()
	local up = right:cross(dir)

	local fakeOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	--General offset
	fakeOffset = fakeOffset + right * 0.25
	fakeOffset = fakeOffset + dir * 0.5
	fakeOffset = fakeOffset + up * 0.25

	--Action offset
	local pitchFraction = pitch / ( math.pi * 0.5 )
	if crouching then
		fakeOffset = fakeOffset + dir * 0.2
		fakeOffset = fakeOffset + up * 0.1
		fakeOffset = fakeOffset - right * 0.05

		if pitchFraction > 0.0 then
			fakeOffset = fakeOffset - up * 0.2 * pitchFraction
		else
			fakeOffset = fakeOffset + up * 0.1 * math.abs( pitchFraction )
		end
	else
		fakeOffset = fakeOffset + up * 0.1 *  math.abs( pitchFraction )
	end

	local fakePosition = fakeOffset + GetOwnerPosition( self.tool )
	return fakePosition
end

function Hook.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if state == 3 then
		if self.cl.throwForce < minThrowForce then
			self.cl.throwForce = minThrowForce
		end

		self.network:sendToServer("sv_reset", self.cl.playerId)

		local dir = sm.localPlayer.getDirection()
		self.network:sendToServer("sv_throwHook", { pos = self:calculateTpMuzzlePos() + dir, dir = dir, throwForce = self.cl.throwForce, owner = self.cl.player })
		self.cl.throwForce = 0
	end
end

function Hook.cl_onSecondaryUse( self, state )
	
end

function Hook.client_onEquippedUpdate( self, primaryState, secondaryState)
	if primaryState ~= self.prevPrimaryState then
		self:cl_onPrimaryUse( primaryState )
		self.prevPrimaryState = primaryState
	end

	--raft
	self.cl.primaryState = primaryState
	self.cl.secondaryState = secondaryState

	if self.cl.throwForce > 0 and not self.cl.isThrowing then
		sm.gui.setProgressFraction(self.cl.throwForce/maxThrowForce)
	end

	if self.cl.pullMultiplier > 0 then
		sm.gui.setProgressFraction(self.cl.pullMultiplier/maxPullMultiplier)
	end
	--raft

	if secondaryState ~= self.prevSecondaryState then
		self:cl_onSecondaryUse( secondaryState )
		self.prevSecondaryState = secondaryState
	end

	return true, true
end
