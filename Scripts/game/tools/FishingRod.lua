dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_loot.lua"
dofile "$CONTENT_DATA/Scripts/game/raft_items.lua"
dofile("$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua")

Rod = class()

local renderables = { "$CONTENT_DATA/Characters/Char_Tools/Char_fishingrod/char_char_fishingrod_preview.rend" }
local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local CHAPTER2 = false

local maxThrowForce = 2.5
local minThrowForce = 0.25
local chargeUpTime = 2
local hookSize = sm.vec3.one()*0.2

local baits = {
	obj_hook_render,
	obj_consumable_sunshake,
	obj_fish,
	obj_consumable_longsandwich
}

local baitNames = {
	none = obj_hook_render,
	sunshake = obj_consumable_sunshake,
	sandwich = obj_consumable_longsandwich
}

local minWait = 5*40 --ticks
local maxWait = 20*40 --ticks
local minBites = 1
local maxBites = 5
local nibbleTime = 5 --ticks
local fishDistance = 3
local junkLootChance = 0.2 --only if no bait
local epicLootChance = 0.05 --for all baits

local junkLoot = {
	{ uuid = blk_plastic, 					chance = 35,			quantity = function() return math.random(8, 16) end },
	{ uuid = blk_scrapwood, 				chance = 30,			quantity = function() return math.random(5, 10) end },
	{ uuid = blk_scrapmetal, 				chance = 15,			quantity = function() return math.random(2, 5) end },
	{ uuid = obj_consumable_chemical, 		chance = 1,				quantity = function() return math.random(1, 10) end },
	{ uuid = obj_decor_boot, 				chance = 5,				quantity = 1 },
	{ uuid = obj_decor_toiletroll, 			chance = 1,				quantity = 1 },
	{ uuid = obj_scrap_smallwheel, 			chance = 1,				quantity = 1 },
	{ uuid = obj_resources_slimyclam, 		chance = 5,				quantity = function() return math.random(8, 16) end },
	{ uuid = obj_resource_ember, 			chance = 5,				quantity = 1 },
	{ uuid = obj_consumable_water, 			chance = 1,				quantity = 1 },
	{ uuid = obj_spaceship_microwave, 		chance = 1,				quantity = 1 }
}

local epicLoot = {
	{ uuid = obj_consumable_component,		chance = 1,				quantity = function() return math.random(1, 3) end },
	{ uuid = obj_consumable_fertilizer, 	chance = 1,				quantity = function() return math.random(2, 4) end },
	{ uuid = obj_consumable_soilbag, 		chance = 1,				quantity = function() return math.random(1, 3) end },
	{ uuid = obj_resource_cotton, 			chance = 5,				quantity = function() return math.random(1, 3) end },
	{ uuid = obj_decor_babyduck, 			chance = 5,				quantity = 1 },
	{ uuid = obj_consumable_battery, 		chance = 5,				quantity = function() return math.random(2, 4) end },
	{ uuid = obj_consumable_sunshake, 		chance = 5,				quantity = 1 }
}

--SERVER Start
function Rod.server_onCreate( self )
	self.sv = {}
	self.sv.effects = {}
	self.sv.effects.hooks = {}

	self.hookIDs = 2

	self.fishList = sm.json.open("$CONTENT_DATA/Scripts/game/tools/fish.json")
end

function Rod.server_onFixedUpdate( self, timeStep )
	for id, effect in pairs(self.sv.effects.hooks) do
		effect.pos, effect.dir = self.calculate_trajectory(effect.pos, effect.dir, timeStep)
		
		if effect.trigger then
			effect.trigger:setWorldPosition(effect.pos)
			local rot, delta = self:get_hook_rotation(effect.pos, effect.player)
			effect.trigger:setWorldRotation(rot)

			local success, length = sm.physics.distanceRaycast(effect.pos, effect.dir*timeStep*6)
			if success then
				self.network:sendToClients("cl_destroy_hook", id)
				self.network:sendToClient(effect.player, "cl_reset")
				self.sv.effects.hooks[id] = nil
				break
			end

			for k,v in ipairs(effect.trigger:getContents()) do
				if sm.exists(v) then
					local ud = v:getUserData()
					if ud and (ud.water or ud.chemical or ud.oil) then
						effect.ud = ud
						self:sv_create_fish(id)

						sm.effect.playEffect("Water - HitWaterTiny", effect.pos, sm.vec3.zero(), sm.quat.identity(), nil, get_effect_data(effect.dir))
						self.network:sendToClients("cl_update_hook", {dir = sm.vec3.zero(), id = id, offset = -0.25})
						self.network:sendToClient(effect.player, "cl_set_fishing")
						effect.dir = sm.vec3.zero()
						effect.trigger = nil
						break
					end
				end
			end
		end

		if effect.fish then
			local fish = effect.fish
			if not fish.effect and fish.spawn < sm.game.getCurrentTick() then
				local pos = effect.pos + sm.vec3.new(math.random()-0.5, math.random()-0.5, 0):normalize()*fishDistance
				self.network:sendToClients("cl_create_fish", {pos = pos, rot = sm.quat.identity(), bitesLeft = fish.bitesLeft, biteTime = fish.biteTime, uuid = fish.uuid, id = id, direction = 1})
				fish.effect = true
			end
		end
	end
end

function Rod.sv_create_fish( self, id)
	local effect = self.sv.effects.hooks[id]
	local x = math.floor( effect.pos.x / 64 )
	local y = math.floor( effect.pos.y / 64 )
	local time = sm.storage.load( STORAGE_CHANNEL_TIME ).timeOfDay
	local ud = effect.ud
	
	local possibleFish = {}
	for k, fish in ipairs(self.fishList) do
		if (x >= fish.location.xMin and x <= fish.location.xMax) and (y >= fish.location.yMin and y <= fish.location.yMax) then
			if time >= fish.time.min and time <= fish.time.max then
				if (fish.triggers.water and ud.water) or (fish.triggers.chemical and ud.chemical) or (fish.triggers.oil and ud.oil) then
					for _, bait in ipairs(fish.baits) do
						if effect.bait == baitNames[bait] then
							possibleFish[#possibleFish + 1] = fish
							break
						end
					end
				end
			end
		end
	end

	local sum = 0
	for _,fish in ipairs( possibleFish ) do
		sum = sum + fish.rarity
	end

	local rand = math.random() * sum
	sum = 0
	for _,fish in ipairs( possibleFish ) do
		sum = sum + fish.rarity

		if rand <= sum then
			local fishEffect = {}
			fishEffect.uuid = sm.uuid.new(fish.uuid)
			fishEffect.spawn = sm.game.getCurrentTick() + math.random(minWait, maxWait)
			fishEffect.bitesLeft = math.random(minBites, maxBites)
			fishEffect.biteTime = fish.biteTime
			
			self.sv.effects.hooks[effect.id].fish = fishEffect
			break
		end
	end
end


function Rod.sv_create_hook( self, params, player )
	local trigger = sm.areaTrigger.createBox(hookSize/2, params.pos, sm.quat.identity(), sm.areaTrigger.filter.areaTrigger)
	local bait = params.bait

	sm.container.beginTransaction()
	sm.container.spend(player:getInventory(), bait, 1)
	if not sm.container.endTransaction() and bait ~= baits[1] then
		bait = baits[1]
		self.network:sendToClient(player, "cl_reset_bait")
	end

	self.sv.effects.hooks[self.hookIDs] = {pos = params.pos, dir = params.dir, trigger = trigger, id = self.hookIDs, bait = bait, player = player}
	self.network:sendToClients("cl_create_hook", {pos = params.pos, dir = params.dir, bait = bait, id = self.hookIDs, player = player})
	self.hookIDs = self.hookIDs + 1
end

function Rod.sv_destroy_hook( self, params, player )
	local effect = self.sv.effects.hooks[params.id]
	if effect and not effect.trigger then
		sm.effect.playEffect("Water - HitWaterTiny", effect.pos, sm.vec3.zero(), sm.quat.identity(), nil, get_effect_data(sm.vec3.one()*0.1))
	end

	if params.returnBait and effect.bait ~= baits[1] then
		sm.container.beginTransaction()
		sm.container.collect(player:getInventory(), effect.bait, 1)
		sm.container.endTransaction()
	end

	if params.catch then
		local catch = {uuid = params.catch, quantity = 1}

		local junkChance = 0
		if effect.bait == baits[1] then
			junkChance = junkLootChance + epicLootChance
		end
		local rand = math.random()
		if rand < epicLootChance then
			catch = SelectOne(epicLoot)
		elseif rand < junkChance then
			catch = SelectOne(junkLoot)
		end


		sm.container.beginTransaction()
		sm.container.collect( player:getInventory(), catch.uuid, catch.quantity )
		sm.container.endTransaction()
		self.network:sendToClient(player, "cl_on_catch", catch )
		sm.effect.playEffect("Loot - Pickup", effect.pos)
	end

	self.network:sendToClients("cl_destroy_hook", params.id)
	self.sv.effects.hooks[params.id] = nil
end

function Rod.server_onRefresh( self )
	self:server_onCreate()
end

function Rod.sv_spend_bait(self, params, player)
	if params.bait ~= baits [1] then
		sm.container.beginTransaction()
		sm.container.spend(player:getInventory(), params.bait, 1)
		if not sm.container.endTransaction() then
			self.network:sendToClient(player, "cl_out_of_bait")
			self.network:sendToClient(player, "cl_cancel", true)
		end
	end
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
--SERVER End


--CLIENT Start
function Rod.client_onCreate( self )
	self.chargeTime = 0
	self.bait = 1

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

	local ropeEffect = sm.effect.createEffect("ShapeRenderable")
	ropeEffect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	ropeEffect:setParameter("color", sm.color.new(1,1,1))
	ropeEffect:start()

	self.cl.effects.hooks[params.id] = {pos = params.pos, dir = params.dir, hook = hookEffect, rope = ropeEffect, player = params.player, bait = params.bait, offset = 0}
end

function Rod.cl_create_fish( self, params )
	local fish = params
	fish.effect = sm.effect.createEffect("ShapeRenderable")
	fish.effect:setParameter("uuid", obj_black_fish)
	fish.effect:setParameter("color", sm.color.new(0,0,0))
	fish.effect:setScale(hookSize*2)
	fish.effect:start()

	self.cl.effects.hooks[params.id].fish = fish
end

function Rod.cl_destroy_hook( self, id )
	local effect = self.cl.effects.hooks[id]
	effect.hook:destroy()
	effect.rope:destroy() 
	if effect.fish then
		effect.fish.effect:destroy()
	end
	self.cl.effects.hooks[id] = nil
end

function Rod.cl_update_hook( self, params )
	local id = params.id
	local effect = self.cl.effects.hooks[id]
	effect.dir = params.dir
	effect.offset = params.offset

	self.cl.effects.hooks[id] = effect
end

function Rod.cl_set_fishing( self )
	self.isThrowing = false
	self.isFishing = true
end

function Rod.cl_reset_bait( self )
	self.bait = 1
	sm.gui.displayAlertText(language_tag("FishingBait") .. language_tag("FishingBaitNone"))
end

function Rod.client_onEquippedUpdate( self, primaryState, secondaryState)
	if self.chargeTime > 0 and not (self.isThrowing or self.isFishing) then
		sm.gui.setProgressFraction(self.chargeTime/chargeUpTime)
	end
	self.primaryState = primaryState

	if primaryState == 1 then
		if self.isThrowing or self.isFishing then
			self:cl_cancel()
			self.returned = true
		end
	elseif primaryState == 3 then
		if self.returned then
			self.returned = false
		elseif not self.isThrowing and not self.isFishing and not self:cl_should_stop_fishing() then
			self.isThrowing = true
			self.useCD = { active = true, timer = 1 }

			local lookDir = sm.localPlayer.getDirection()
			if lookDir.z > 0.5 then
				lookDir.z = 0
				lookDir = lookDir:normalize()
				lookDir.z = 0.333
				lookDir = lookDir:normalize()
			end


			local hookPos = self:calculateFirePosition(sm.localPlayer.getPlayer()) + lookDir / 2
			local hookDir = lookDir * math.max(self.chargeTime/chargeUpTime * maxThrowForce, minThrowForce)

			self.network:sendToServer("sv_create_hook", {pos = hookPos, dir = hookDir, bait = baits[self.bait]})
			sm.audio.play( "Sledgehammer - Swing" )
		end
	end

	return true, true
end

function Rod:cl_should_stop_fishing()
	local owner = self.tool:getOwner()
	return owner.character:isSwimming() or owner.character:isDiving() or self.tool:isSprinting()
end

function Rod.client_onUpdate( self, dt )
	if self.useCD.active then
		self.useCD.timer = self.useCD.timer - dt
		if self.useCD.timer <= 0 then
			self.useCD = { active = false, timer = 1 }
		end
	end

	if self.tool:isEquipped() and not self.returned and (self.primaryState == 1 or self.primaryState == 2) then
		self.chargeTime = math.min( self.chargeTime + dt, chargeUpTime)
	end

	if self:cl_should_stop_fishing() then
		self:cl_cancel()
	end

	self:client_updateAnimations(dt)

	for id, effect in pairs(self.cl.effects.hooks) do
		effect.pos, effect.dir = self.calculate_trajectory(effect.pos, effect.dir, dt)
		effect.offset = effect.offset - effect.offset*dt*5

		local rot, delta = self:get_hook_rotation(effect.pos, effect.player)
		local scale = sm.vec3.new(0.01, 0.01, delta:length())

		effect.hook:setPosition(effect.pos + sm.vec3.new(0,0,1)*effect.offset)
		effect.hook:setRotation(rot)

		effect.rope:setPosition(effect.pos + delta * 0.5)
		effect.rope:setScale(scale)
		effect.rope:setRotation(rot)

		if effect.fish then
			rot, effect.fish.pos, destroy = self:animate_fish(effect, effect.pos, dt)

			effect.fish.effect:setPosition(effect.fish.pos)
			effect.fish.effect:setRotation(rot)
			if destroy then
				effect.fish.effect:destroy()
				effect.fish = nil
				if effect.player == sm.localPlayer.getPlayer() then
					self.network:sendToServer("sv_create_fish", id)
				end
			end
		end
	end 
end

function Rod:cl_cancel(noRefund)

	if self.isFishing or self.isThrowing then
		self.useCD.active = true
		sm.audio.play( "Sledgehammer - Swing" )

		for id, effect in pairs(self.cl.effects.hooks) do
			if effect.player == sm.localPlayer.getPlayer() then
				local catch = nil
				if effect.fish and effect.fish.final and not effect.fish.escape then
					noRefund = true
					catch = effect.fish.uuid
				end

				self.network:sendToServer("sv_destroy_hook", {id = id, returnBait = not noRefund, catch = catch})
			end
		end
	end

	self:cl_reset()
end

function Rod:cl_reset()
	self.chargeTime = 0
	self.isThrowing = false
	self.isFishing = false
	self.primaryState = nil
	self.returned = false
end

function Rod:client_onToggle()
	if CHAPTER2 then
		for i=0, #baits-1 do
			local index = (self.bait + i) % #baits + 1
			if index == 1 then
				self.bait = index
				break
			elseif sm.localPlayer.getInventory():canSpend(baits[index], 1 ) then
				self.bait = index
				sm.gui.displayAlertText(language_tag("FishingBait") .. sm.shape.getShapeTitle(baits[index]))
				return true
			end
		end
		sm.gui.displayAlertText(language_tag("FishingBait") .. language_tag("FishingBaitNone"))
	end
	return true
end

function Rod.calculateFirePosition( self, player )
	local character = player:getCharacter()

	local dir = character:getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.vec3.cross(dir, sm.vec3.new(0,0,1))
	if right:length() > 0.0001 then
		right = right:normalize()
	else
		right = sm.vec3.new(0, 1, 0)
	end

	local fireOffset = dir
	fireOffset.z = 0.0
	fireOffset = fireOffset:normalize()*1.2
	fireOffset.z = 1

	fireOffset = fireOffset + right * 0.25
	fireOffset = fireOffset:rotate( math.rad( pitch ), right )

	local firePosition = character:getWorldPosition() + fireOffset
	return firePosition
end

function Rod.client_onUnequip( self, animate )
	self:cl_cancel()

	self:client_UnequipAnimation(animate)
end

function Rod.client_onRefresh( self )
	self:client_onCreate()

	self:loadAnimations()
end

function Rod.calculate_trajectory(pos, dir, dt)
	if dir == sm.vec3.zero() then
		return pos, dir
	end

	dir = (dir - sm.vec3.new(0,0,1)*dt):normalize() * dir:length()
	pos = pos + dir*dt*5
	return pos, dir
end

function Rod.get_hook_rotation(self, pos, player)
	local delta = self:calculateFirePosition(player) - pos
	return sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta), delta
end

function Rod.animate_fish(self, effect, hookPos, dt)
	local fish = effect.fish
	local dir = hookPos - fish.pos
	local distance = dir:length()
	local newPos = fish.pos
	
	local speed = fishDistance-distance*0.99
	if fish.escape then
		speed = math.max(distance, fishDistance)
	end

	local nextPos = fish.pos + dir:normalize() * (math.max(speed, 0.5)) * dt * fish.direction
	local nextDir = hookPos - nextPos
	local nextDistance = nextDir:length()
	if (fish.direction > 0 and (nextDistance <= 0.15 or (newPos - nextPos):length() > distance) ) or (fish.direction < 0 and nextDistance >= 0.99*fishDistance and not fish.final) then
		if fish.direction < 0 or (fish.nibble and fish.nibble < sm.game.getCurrentTick()) then
			fish.nibble = nil
			fish.direction = fish.direction*(-1)
			if fish.final then
				fish.escape = true
				if effect.player == sm.localPlayer.getPlayer() then
					self.network:sendToServer("sv_spend_bait", {bait = effect.bait, id = effect.id})
				end
			end
		elseif not fish.nibble then
			if fish.direction > 0 then
				fish.bitesLeft = fish.bitesLeft - 1
			end

			if fish.bitesLeft == 0 then
				fish.final = true
				fish.nibble = sm.game.getCurrentTick() + fish.biteTime*40
				sm.effect.playEffect("Water - HitWaterBig", effect.pos, sm.vec3.zero(), sm.quat.identity(), nil, get_effect_data(sm.vec3.one()))
				sm.effect.playEffect("Eat - MunchSound", effect.pos)
				sm.audio.play("Retrofmblip")
				effect.offset = -1.5
			else
				fish.nibble = sm.game.getCurrentTick() + nibbleTime
				sm.effect.playEffect("Water - HitWaterTiny", effect.pos, sm.vec3.zero(), sm.quat.identity(), nil, get_effect_data(sm.vec3.one()*0.01))
				sm.effect.playEffect("Eat - MunchSound", effect.pos)
				effect.offset = -0.5
			end
		end
	else
		newPos = nextPos
	end

		
	if fish.escape then dir = -dir end
	--fish.rot = sm.vec3.getRotation(sm.vec3.new(0,0,1), sm.vec3.new(-1,0,0))
	fish.rot = sm.vec3.getRotation(sm.vec3.new(1,0,0), (dir:normalize() + dir:cross(sm.vec3.new(0,0,1)):normalize()*0.25*math.cos(sm.game.getCurrentTick()/10)):normalize())
	fish.rot = fish.rot*sm.vec3.getRotation(sm.vec3.new(0,0,1), sm.vec3.new(-1,0,0))
	fish.rot = fish.rot*sm.vec3.getRotation(sm.vec3.new(0,0,1), sm.vec3.new(0,0,-1))

	return fish.rot, newPos, distance > fishDistance*3
end

function Rod.cl_out_of_bait(self)
	self:cl_reset_bait()
	sm.gui.displayAlertText(language_tag("FishingOutOfBait"))
end

function Rod:cl_on_catch( params )
	sm.gui.displayAlertText( language_tag("FishingGetItem") .. " #ff9d00" .. sm.shape.getShapeTitle(params.uuid) .. " #df7f00x" .. tostring(params.quantity) )
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