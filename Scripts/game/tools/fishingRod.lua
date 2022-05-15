dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_loot.lua"

Rod = class()

local CONTENT_DATA = "$CONTENT_667b4c22-cc1a-4a2b-bee8-66a6c748d40e"
local renderables = {
	CONTENT_DATA.."/Characters/Char_Tools/Char_fishingrod/char_char_fishingrod_preview.rend"
}

local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local normalLoot = {
	{ uuid = obj_fish,						chance = 112,			quantity = 1 },
	{ uuid = blk_plastic, 					chance = 20,			quantity = function() return math.random(8, 16) end },
	{ uuid = blk_scrapwood, 				chance = 15,			quantity = function() return math.random(5, 10) end },
	{ uuid = blk_scrapmetal, 				chance = 10,			quantity = function() return math.random(2, 5) end },
	{ uuid = obj_consumable_soilbag, 		chance = 8,				quantity = function() return math.random(1, 2) end },
	{ uuid = obj_resource_cotton, 			chance = 5,				quantity = 1 },
	{ uuid = obj_decor_boot, 				chance = 5,				quantity = 1 }
}

local rareLoot = {
	{ uuid = obj_consumable_component,		chance = 1,				quantity = function() return math.random(1, 2) end },
	{ uuid = obj_consumable_fertilizer, 	chance = 1,				quantity = function() return math.random(1, 3) end },
	{ uuid = obj_consumable_chemical, 		chance = 1,				quantity = function() return math.random(1, 10) end },
	{ uuid = obj_consumable_soilbag, 		chance = 1,				quantity = function() return math.random(2, 4) end }
}

function vec3Num( num )
	return sm.vec3.new(num,num,num)
end

local hookSize = vec3Num(0.1)
local premiumDropChance = 0.1
local maxThrowForce = 5
local minThrowForce = 0.25
local minWaitTime = 7.5*40
local maxWaitTime = 25*40

local CatchTime = 0.75
local minBites = 1
local maxBites = 6

function Rod.server_onCreate( self )
	self.hooks = {}
end

function Rod.server_onRefresh( self )
	self:server_onCreate()
end

function Rod.client_onCreate( self )
	self.player = sm.localPlayer.getPlayer()

	self.ropeEffect = sm.effect.createEffect("ShapeRenderable")
	self.ropeEffect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	self.ropeEffect:setParameter("color", sm.color.new(1,1,1))

	self.hookEffect = sm.effect.createEffect("ShapeRenderable")
	self.hookEffect:setParameter("uuid", sm.uuid.new("4a971f7d-14e6-454d-bce8-0879243c7642"))
	self.hookEffect:setParameter("color", sm.color.new(0,0,0))
	self.hookEffect:setScale(hookSize)
	self.hookOffset = 0

	self.throwForce = 0
	self.primaryState = 0
	self.fishBites = 0
	self.isThrowing = false
	self.isFishing = false
	self.catchTimer = 0
	self.hookPos = sm.vec3.zero()
	self.hookDir = sm.vec3.zero()
	self.lookDir = sm.vec3.zero()
	self.trigger = nil
	self.triggers = {}

	self.dropTimer = 0
	self.useCD = { active = false, timer = 1 }
end

function Rod.client_onRefresh( self )
	self:loadAnimations()
end

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


	--Remove?
	self.movementDispersion = 0.0
	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3
	self.blendTime = 0.2
	self.jointWeight = 0.0
	self.spineWeight = 0.0
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
end

function Rod:sv_itemDrop(args, player)
	local lootList = normalLoot
	if math.random() <= premiumDropChance then
		lootList = rareLoot
	end
	local drop = SelectOne(lootList)

	sm.container.beginTransaction()
	sm.container.collect( player:getInventory(), drop.uuid, drop.quantity, 1 )
	sm.container.endTransaction()

	self.network:sendToClient(player, "cl_itemDrop", drop )
end

function Rod:cl_itemDrop( drop )
	sm.gui.displayAlertText( "#{RAFT_FISHED} #ff9d00"..sm.shape.getShapeTitle(drop.uuid).." #df7f00x"..tostring(drop.quantity) )
end

function Rod:sv_manageTrigger( args, player )
	if args.state == "create" then
		self.hooks[tostring(player.id)] = {create = true, pos = args.pos}
	elseif args.state == "destroy" then
		self.hooks[tostring(player.id)] = {create = false, pos = args.pos}
	else
		self.hooks[tostring(player.id)] = {pos = args.pos}
	end
end

function Rod:cl_setTriggers( triggers )
	for playerID, _ in pairs(triggers) do
		local player = nil
		for _, players in pairs(sm.player.getAllPlayers()) do
			if tostring(players.id) == playerID then
				player = players
			end
		end

		if player then
			--self
			if playerID == tostring(sm.localPlayer.getPlayer().id) then
				for k, v in pairs(triggers[playerID]) do
					if k == "pos" and sm.exists(self.trigger) then
						self.trigger:setWorldPosition( v )
					elseif k == "create" then
						if v then
							self.trigger = sm.areaTrigger.createBox( hookSize * 4, self.hookPos, sm.quat.identity(), 8 )
						elseif sm.exists(self.trigger) then
							sm.areaTrigger.destroy(self.trigger)
							break
						end
					end
				end
			else
				--other
				if self.triggers[playerID] then
					for k, v in pairs(triggers[playerID]) do
						if k == "pos" and sm.exists(self.triggers[playerID].hook) then
							self.triggers[playerID].hook:setPosition( v )

							local offset = v

							local delta = ( self:calculateFirePositionMP( player ) - offset)
							local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
							local distance = sm.vec3.new(0.01, 0.01, delta:length())

							self.triggers[playerID].rope:setPosition(offset + delta * 0.5)
							self.triggers[playerID].rope:setScale(distance)
							self.triggers[playerID].rope:setRotation(rot)
							self.triggers[playerID].hook:setRotation( rot )
							self.triggers[playerID].hook:start()
							self.triggers[playerID].rope:start()
						elseif k == "create" then
							if not v then
								self.triggers[playerID].hook:stop()
								self.triggers[playerID].rope:stop()
							end
						end
					end
				else
					local rope = sm.effect.createEffect("ShapeRenderable")
					rope:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
					rope:setParameter("color", sm.color.new(1,1,1))
				
					local hook = sm.effect.createEffect("ShapeRenderable")
					hook:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
					hook:setParameter("color", sm.color.new(1,0,0))
					hook:setScale(hookSize)
					self.triggers[playerID] = {rope = rope, hook = hook}
				end
			end

		end
	end
end

function Rod:server_onFixedUpdate( dt )
	self.network:sendToClients("cl_setTriggers", self.hooks)
end

function Rod:sv_playEffect( args )
	self.network:sendToClients("cl_playEffect", args)
end

function Rod:cl_playEffect( args )
	if args.type == "effect" then
		sm.effect.playEffect( args.effect, args.pos, sm.vec3.zero(), sm.quat.identity(), sm.vec3.one())
	else
		sm.audio.play( args.effect, args.pos )
	end
end

function Rod:sv_playWaterSplash( args )
	self.network:sendToClients("cl_playWaterSplash", { pos = args.pos, effect = args.effect, force = args.force })
end

function Rod:cl_playWaterSplash( args )
	local params = {
		["Size"] = min( 1.0, args.force * 0.5 / 76800.0 ),
		["Velocity_max_50"] = sm.vec3.new(0,0,10 * args.force * 0.1 ):length(),
		["Phys_energy"] = args.force / 1000.0
	}
	sm.effect.playEffect( args.effect, args.pos, sm.vec3.zero(), sm.quat.identity(), sm.vec3.one(), params )
	self.hookOffset = 0.25
	if args.effect == "Water - HitWaterBig" then
		self.hookOffset = 1
	end
end

function Rod:cl_reset()
	self.throwForce = 0
	self.isThrowing = false
	self.isFishing = false
	self.hookPos = sm.vec3.zero()
	self.hookDir = sm.vec3.zero()
	self.dropTimer = 0
	self.ropeEffect:stop()
	self.hookEffect:stop()
end

function Rod:cl_cancel( state )
	if (state == 1 or state == 2) then
		if self.catchTimer > 0 and self.isFishing then
			self.network:sendToServer("sv_itemDrop")
			sm.effect.playEffect("Loot - Pickup", self.hookPos)

			self.network:sendToServer("sv_playWaterSplash", { pos = self.hookPos, effect = "Water - HitWaterMassive", force = 10000 } )
		elseif self.isFishing then
			self.network:sendToServer("sv_playWaterSplash", { pos = self.hookPos, effect = "Water - HitWaterTiny", force = 10000 } )
			
			if sm.game.getCurrentTick() < self.dropTimer then
				sm.gui.displayAlertText("Don't get fooled!\nWait for the massive splash!", 5)
			end
			
			print(self.catchTimer)
			print(self.dropTimer)
		end

		if self.isFishing or self.isThrowing then
			self.useCD.active = true
			sm.audio.play( "Sledgehammer - Swing" )
		end

		self.network:sendToServer("sv_manageTrigger", {pos = self.hookPos, state = "destroy"})

		self:cl_reset()
	end
	return self.useCD.active
end

function Rod:cl_calculateRodEffectData()
	local offset = self.hookPos - sm.vec3.new(0, 0, self.hookOffset)

	local delta = ( self:calculateFirePosition() - offset )
	local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
	local distance = sm.vec3.new(0.01, 0.01, delta:length())

	self.ropeEffect:setPosition(offset + delta * 0.5)
	self.ropeEffect:setScale(distance)
	self.ropeEffect:setRotation(rot)

	self.hookEffect:setPosition(offset)
	self.hookEffect:setRotation(rot)
end

function Rod:client_onFixedUpdate( dt )
	local owner = self.tool:getOwner()
	if self.useCD.active or owner.character:isSwimming() or owner.character:isDiving() or self.tool:isSprinting()then
		self.throwForce = 0
		if self.isFishing or self.isThrowing then
			self:cl_cancel(1)
		end
		return
	end

	--if self.isFishing or self.isThrowing then
		--print()
	--end

	if self.tool:isEquipped() and self.primaryState == 1 or self.primaryState == 2 then
		self.throwForce = self.throwForce < maxThrowForce and self.throwForce + dt*2 or maxThrowForce
	end

	self.hookOffset = self.hookOffset * (1 - dt*4)
	self.catchTimer = self.catchTimer - dt

	if sm.exists(self.ropeEffect) and self.ropeEffect:isPlaying() then
		if self.isThrowing then
			if self.hookDir.z > -1 then
				self.throwForce = math.max(0.01, self.throwForce)
				self.hookDir = self.hookDir - sm.vec3.new(0,0,0.05 / self.throwForce)
			end
			self.hookPos = self.hookPos + vec3Num(self.throwForce) * 3 * self.hookDir * dt
			self.network:sendToServer("sv_manageTrigger", {pos = self.hookPos})

			local hitWater = false
			if sm.exists(self.trigger) then
				for _, result in ipairs( self.trigger:getContents() ) do
					if sm.exists( result ) then
						local userData = result:getUserData()
						if userData then
							hitWater = true
						end
					end
				end
			end
			local hit, result = sm.physics.raycast( self.hookPos, self.hookPos + self.hookDir * self.throwForce * (dt*2) )

			if hitWater then
				self.isThrowing = false
				self.isFishing = true
				self.throwForce = 0
				self.dropTimer = sm.game.getCurrentTick() + math.random(minWaitTime,maxWaitTime)
				self.fishBites = math.random(minBites, maxBites)
				self.network:sendToServer("sv_manageTrigger", {pos = self.hookPos, state = "destroy"})
				self.network:sendToServer("sv_playWaterSplash", { pos = self.hookPos, effect = "Water - HitWaterTiny", force = 10000 / math.ceil(self.dropTimer) } )
			elseif not hitWater and hit then
				self:cl_reset()
			end
		end

		if self.hookDir:length() > 0 and self.hookPos:length() > 0 then
			self:cl_calculateRodEffectData()
		end
	end

	if self.dropTimer > sm.game.getCurrentTick() and self.isFishing then
		local dif = self.dropTimer - sm.game.getCurrentTick()

		if dif % 40 == 0 then
			if dif / 40 - 2 < self.fishBites then
				if self.fishBites > 1 then
					self.network:sendToServer("sv_playWaterSplash", { pos = self.hookPos, effect = "Water - HitWaterTiny", force = 10000 / math.ceil(self.dropTimer) } )
					self.network:sendToServer("sv_playEffect", { effect = "Eat - MunchSound", pos = self.hookPos, type = "effect" } )
					self.fishBites = self.fishBites - 1
				elseif self.fishBites == 1 then
					self.network:sendToServer("sv_playWaterSplash", { pos = self.hookPos, effect = "Water - HitWaterBig", force = 10000 / math.ceil(self.dropTimer) } )
					self.network:sendToServer("sv_playEffect", { effect = "Eat - MunchSound", pos = self.hookPos, type = "effect" } )
					self.network:sendToServer("sv_playEffect", { effect = "Retrofmblip", pos = self.hookPos, type = "sound" } )
					self.fishBites = self.fishBites - 1
					self.catchTimer = CatchTime
				end
			end
		end
	elseif self.catchTimer < 0 then
		self.dropTimer = sm.game.getCurrentTick() + math.random(minWaitTime,maxWaitTime)
		self.fishBites = math.random(minBites, maxBites)
	end

end

function Rod.client_onUpdate( self, dt )
	self.lookDir = sm.localPlayer.getDirection()

	if self.useCD.active then
		self.useCD.timer = self.useCD.timer - dt
		if self.useCD.timer <= 0 then
			self.useCD = { active = false, timer = 1 }
		end
	end

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
	-- Timers
	self.sprintCooldownTimer = math.max( self.sprintCooldownTimer - dt, 0.0 )

	-- Sprint block
	local blockSprint = self.sprintCooldownTimer > 0.0
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

function Rod.client_onUnequip( self, animate )
	self:cl_reset()

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

function Rod.cl_onPrimaryUse( self, state )
	local owner = self.tool:getOwner()
	if owner.character == nil or self.lookDir == sm.vec3.zero() or self.useCD.active or owner.character:isSwimming() or owner.character:isDiving() or self.tool:isSprinting() then
		return
	end

	local shouldReturn = self:cl_cancel( state )
	if shouldReturn then return end

	if state == 3 then
		if self.throwForce < minThrowForce then
			self.throwForce = minThrowForce
		end

		self.isThrowing = true
		self.hookPos = self:calculateFirePosition() + self.lookDir / 2
		self.hookDir = self.lookDir
		self.network:sendToServer("sv_manageTrigger", {pos = self.hookPos, state = "create"})

		self:cl_calculateRodEffectData()
		self.ropeEffect:start()
		self.hookEffect:start()

		self.fishBites = math.random(minBites, maxBites)
		sm.audio.play( "Sledgehammer - Swing" )
	end
end

function Rod.cl_onSecondaryUse( self, state )
	self:cl_cancel( state )
end

function Rod.client_onEquippedUpdate( self, primaryState, secondaryState)
	if primaryState ~= self.prevPrimaryState then
		self:cl_onPrimaryUse( primaryState )
		self.prevPrimaryState = primaryState
	end

	self.primaryState = primaryState
	if self.throwForce > 0 and not self.isThrowing then
		sm.gui.setProgressFraction(self.throwForce/maxThrowForce)
	end

	if secondaryState ~= self.prevSecondaryState then
		self:cl_onSecondaryUse( secondaryState )
		self.prevSecondaryState = secondaryState
	end

	return true, true
end

function Rod.calculateFirePosition( self )
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new( 1.0, 0.0, 0.75 )

	if crouching then
		fireOffset.z = fireOffset.z + 0.15
	else
		fireOffset.z = fireOffset.z + 0.45
	end

	fireOffset = sm.localPlayer.getDirection()
	fireOffset.z = 0.0
	fireOffset = fireOffset:normalize()*1.2
	fireOffset.z = fireOffset.z + 1

	if firstPerson then
		fireOffset = fireOffset + right * 0.05
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate( math.rad( pitch ), right )
	end
	

	local firePosition = GetOwnerPosition( self.tool ) + fireOffset
	return firePosition
end

function Rod.calculateFirePositionMP( self, player )
	--calculate rope offset for other players
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