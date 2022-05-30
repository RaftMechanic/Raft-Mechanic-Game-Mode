dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

Hook = class()

local renderables = { "$CONTENT_DATA/Characters/Char_Tools/Char_pullinghook/char_pullinghook_preview.rend" }
local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local maxThrowForce = 6.9420
local minThrowForce = 1.0
local chargeUpTime = 1.75
local hookSize = sm.vec3.one()*0.25
local returnSpeed = 1
local itemPullSpeed = 2

--SERVER START
function Hook:server_onCreate()
	self.sv = {}
	self.sv.hooks = {}

	self.hookIDs = 2
end

function Hook:server_onFixedUpdate( timeStep )
	for id, effect in pairs(self.sv.hooks) do
		effect.pos, effect.dir = calculate_trajectory(effect.pos, effect.dir, effect.player, timeStep)
		
		if effect.trigger then
			effect.trigger:setWorldPosition(effect.pos)
			local rot, delta = get_hook_rotation(effect.pos, effect.player)
			effect.trigger:setWorldRotation(rot)

			for k,v in ipairs(effect.trigger:getContents()) do
				if sm.exists(v) then
					local ud = v:getUserData()
					if ud and (ud.water or ud.chemical or ud.oil) then
						effect.ud = ud

						sm.effect.playEffect("Water - HitWaterTiny", effect.pos, sm.vec3.zero(), sm.quat.identity(), nil, get_effect_data(effect.dir))

						local pullDir = effect.player:getCharacter():getWorldPosition() - effect.pos
						pullDir.z = 0
						pullDir = pullDir:normalize()*effect.dir:length()*returnSpeed
						self.network:sendToClients("cl_return_hook", {dir = pullDir, id = id})
						self.network:sendToClient(effect.player, "cl_set_pulling")
						effect.dir = pullDir
						effect.trigger = nil

						effect.shapeTrigger = sm.areaTrigger.createBox( hookSize * 12, effect.pos, sm.quat.identity(), sm.areaTrigger.filter.dynamicBody )
					end
				end
			end

			local success, length = sm.physics.distanceRaycast(effect.pos, effect.dir*timeStep*6)
			if success then
				self.network:sendToClients("cl_destroy_hook", id)
				self.network:sendToClient(effect.player, "cl_reset")
				self.sv.hooks[id] = nil
			end
		end

		if effect.shapeTrigger then
			effect.shapeTrigger:setWorldPosition(effect.pos)

			for _, body in ipairs( effect.shapeTrigger:getContents() ) do
				if sm.exists( body ) then
					if body:getMass() < 100 then
						self:sv_applyImpulse( { body = body, player = effect.player, dir = effect.dir, dt = timeStep } )
					end
				end
			end

			local distance = effect.pos - effect.player:getCharacter():getWorldPosition()
			distance.z = 0
			if distance:length() < 0.5 then
				self.network:sendToClients("cl_destroy_hook", id)
				self.network:sendToClient(effect.player, "cl_reset")
				self.sv.hooks[id] = nil
			end
		end
	end
end

function Hook:sv_applyImpulse( params )
	local dir = params.dir
	local body = params.body
	local distance = params.player:getCharacter():getWorldPosition() - body:getWorldPosition()

	if body:getVelocity():length() < itemPullSpeed * 3 * math.max(distance:length()/10, 1) then
		sm.physics.applyImpulse( body, dir*math.sqrt(dir:length()) * body:getMass() * params.dt * math.max(distance:length()/20, 1) * 10, true )
	end
end

function Hook:sv_create_hook( params, player )
	local trigger = sm.areaTrigger.createBox(hookSize, params.pos, sm.quat.identity(), sm.areaTrigger.filter.areaTrigger)
	self.sv.hooks[self.hookIDs] = {pos = params.pos, dir = params.dir, trigger = trigger, id = self.hookIDs, player = player}
	self.network:sendToClients("cl_create_hook", {pos = params.pos, dir = params.dir, id = self.hookIDs, player = player})
	self.hookIDs = self.hookIDs + 1
end

function Hook:sv_destroy_hook( id )
	local effect = self.sv.hooks[id]
	if effect and not effect.trigger then
		sm.effect.playEffect("Water - HitWaterTiny", effect.pos, sm.vec3.zero(), sm.quat.identity(), nil, get_effect_data(sm.vec3.one()*0.1))
	end

	self.network:sendToClients("cl_destroy_hook", id)
	self.sv.hooks[id] = nil
end

function Hook:server_onRefresh()
	self:server_onCreate()
end
--SERVER END



--CLIENT START
function Hook:client_onCreate()
	self.chargeTime = 0
	self.cl = {}
	self.cl.hooks = {}
end

function Hook:client_onUpdate( dt )
	if self.tool:isEquipped() and not (self.isThrowing or self.isPulling) and (self.primaryState == 1 or self.primaryState == 2) then
		self.chargeTime = math.min( self.chargeTime + dt, chargeUpTime)
	end

	if self:cl_should_stop_hooking() then
		self:cl_cancel()
	end

	for id, effect in pairs(self.cl.hooks) do
		effect.pos, effect.dir = calculate_trajectory(effect.pos, effect.dir, effect.player, dt)

		local rot, delta = get_hook_rotation(effect.pos, effect.player)
		local scale = sm.vec3.new(0.01, 0.01, delta:length())

		effect.hook:setPosition(effect.pos)
		effect.hook:setRotation(rot)

		effect.rope:setPosition(effect.pos + delta * 0.5)
		effect.rope:setScale(scale)
		effect.rope:setRotation(rot)


	end 

	self:client_updateAnimations(dt)
end

function Hook:client_onEquippedUpdate( primaryState, secondaryState)
	if self.chargeTime > 0 and not (self.isThrowing or self.isPulling) then
		sm.gui.setProgressFraction(self.chargeTime/chargeUpTime)
	end
	self.primaryState = primaryState

	if secondaryState == 1 then
		self:cl_cancel()
		return true, true
	end

	if primaryState == 1 then
		if self.isThrowing or self.isPulling then
			self:cl_cancel()
		end
	elseif primaryState == 3 then
		if not self.isThrowing and not self.isPulling and not self:cl_should_stop_hooking() then
			self.isThrowing = true

			local lookDir = sm.localPlayer.getDirection()
			if lookDir.z > 0.25 then
				lookDir.z = 0
				lookDir = lookDir:normalize()
				lookDir.z = 0.15
				lookDir = lookDir:normalize()
			end

			local hookPos = calculateFirePosition(sm.localPlayer.getPlayer()) + lookDir / 2
			local hookDir = lookDir * math.max(self.chargeTime/chargeUpTime * maxThrowForce, minThrowForce)

			self.network:sendToServer("sv_create_hook", {pos = hookPos, dir = hookDir})
			sm.audio.play( "Sledgehammer - Swing" )
		end
	end

	return true, true
end

function Hook:cl_create_hook( params )
	local hookEffect = sm.effect.createEffect("ShapeRenderable")
	hookEffect:setParameter("uuid", obj_hook_render)
	hookEffect:setParameter("color", sm.color.new(0,0,0))
	hookEffect:setScale(hookSize)
	hookEffect:start()

	local ropeEffect = sm.effect.createEffect("ShapeRenderable")
	ropeEffect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	ropeEffect:setParameter("color", sm.color.new(0,0,0))
	ropeEffect:start()

	self.cl.hooks[params.id] = {pos = params.pos, dir = params.dir, hook = hookEffect, rope = ropeEffect, player = params.player}
end

function Hook:cl_cancel()
	if self.isThrowing or self.isPulling then
		sm.audio.play( "Sledgehammer - Swing" )

		for id, effect in pairs(self.cl.hooks) do
			if effect.player == sm.localPlayer.getPlayer() then
				self.network:sendToServer("sv_destroy_hook", id)
				if self.isThrowing then
					self:cl_reset()
				end
			end
		end
	end

	self:cl_reset()
end

function Hook:cl_reset()
	self.chargeTime = 0
	self.isThrowing = false
	self.isPulling = false
	self.primaryState = nil
end

function Hook:cl_destroy_hook( id )
	local effect = self.cl.hooks[id]
	if effect then
		effect.hook:destroy()
		effect.rope:destroy()
	end
	self.cl.hooks[id] = nil
end

function Hook:cl_set_pulling()
	self.isThrowing = false
	self.isPulling = true
end

function Hook:cl_return_hook( params )
	self.cl.hooks[params.id].dir = params.dir
end

function Hook:cl_should_stop_hooking()
	local ownerChar = self.tool:getOwner().character
	return ownerChar:isSwimming() or ownerChar:isDiving() or self.tool:isSprinting()
end

function Hook:client_onUnequip( animate )
	self:cl_cancel()

	self:client_UnequipAnimation(animate)
end

function Hook:client_onRefresh()
	self:loadAnimations()
	self:client_onCreate()
end
--CLIENT END



--GLOBAL FUNCTIONS
function calculate_trajectory(pos, dir, player, dt)
	if dir.z ~= 0 then
		dir = (dir - sm.vec3.new(0,0,1)*dt):normalize() * dir:length()
	else
		local speed = dir:length()*returnSpeed
		dir = player:getCharacter():getWorldPosition() - pos
		dir.z = 0
		dir = dir:normalize()*speed
	end
	pos = pos + dir*dt*5
	return pos, dir
end

function get_hook_rotation(pos, player)
	local delta = calculateFirePosition(player) - pos
	return sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta), delta
end

function calculateFirePosition( player )
	local character = player:getCharacter()

	local dir = character:getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.vec3.cross(dir, sm.vec3.new(0,0,1))
	if right:length() > 0 then
		right = right:normalize()
	else
		right = sm.vec3.new(0, 1, 0)
	end

	local fireOffset = dir*0.8 + right*0.3
	return character:getWorldPosition() + fireOffset
end

function get_effect_data(dir)
	local force = dir:length()
	local params = {
		["Size"] = min( 1.0, force ),
		["Velocity_max_50"] = force*10,
		["Phys_energy"] = force*100
	}
	return params
end
--GLOBAL FUNCTIONS END





--ANIMATION STUFF
function Hook.client_updateAnimations( self, dt)
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

function Hook.client_onEquip( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
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

function Hook.client_UnequipAnimation( self, animate )
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

				sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "spudgun_sprint_idle", { looping = true } },
			}
		)
	end

	self.blendTime = 0.2
	self.jointWeight = 0.0
	self.spineWeight = 0.0
end