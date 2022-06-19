dofile "$SURVIVAL_DATA/Scripts/game/units/unit_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Ticker.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_units.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/PathingState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/BreachState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/CombatAttackState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

dofile "$CONTENT_DATA/Scripts/game/raft_loot.lua"

SharkBotUnit = class( nil )

local RoamStartTimeMin = 40 * 4 -- 4 seconds
local RoamStartTimeMax = 40 * 8 -- 8 seconds

local CombatAttackRange = 1.0 -- Range where the unit will perform attacks
local CombatApproachRange = 2000.25 -- Range where the unit will approach the player without obstacle checking

local StaggerProjectile = 0.5
local StaggerMelee = 1.0
local StaggerCooldownTickTime = 1.65 * 40

local AvoidLimit = 3
local AvoidRange = 3.5

local AllyRange = 40.0
local MeleeBreachLevel = 9

local HearRange = 100

local FleeTimeMin = 40 * 14 -- 14 seconds
local FleeTimeMax = 40 * 20 -- 20 seconds
local fleeSpeed = 3
local attackSpeed = 2.5
local rushRange = 15
local BreachTime = 40*20 --20 seconds

function SharkBotUnit.server_onCreate( self )
	
	self.target = nil
	self.previousTarget = nil
	self.lastTargetPosition = nil
	self.ambushPosition = nil
	self.predictedVelocity = sm.vec3.new( 0, 0, 0 )
	self.lastTargetPosition = nil
	self.flee = false
	self.breachTimer = 0
	self.land = 0
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 150, maxhp = 150 }
	end

	if g_eventManager then
		self.tileStorageKey = g_eventManager:sv_getTileStorageKeyFromObject( self.unit.character )
	end

	if self.params then
		if self.params.tetherPoint then
			self.homePosition = self.params.tetherPoint + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			if self.params.ambush == true then
				self.ambushPosition = self.params.tetherPoint + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			end
			if self.params.raider == true then
				self.saved.raidPosition = self.params.tetherPoint + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			end
		end
		if self.params.raider then
			self.saved.raider = true
		end
		if self.params.temporary then
			self.saved.temporary = self.params.temporary
			self.saved.deathTickTimestamp = sm.game.getCurrentTick() + getTicksUntilDayCycleFraction( DAYCYCLE_DAWN )
		end
		if self.params.deathTick then
			self.saved.deathTickTimestamp = self.params.deathTick
		end
		if self.params.color then
			self.saved.color = self.params.color
		end
		if self.params.groupTag then
			self.saved.groupTag = self.tileStorageKey .. ":" .. self.params.groupTag
		end
	end
	if self.saved.color then
		self.unit.character:setColor( self.saved.color )
	end
	if not self.homePosition then
		self.homePosition = self.unit.character.worldPosition
	end
	self.storage:save( self.saved )
	self.unit.publicData = { groupTag = self.saved.groupTag }

	self.unit.eyeHeight = self.unit.character:getHeight() * 0.75
	self.unit.visionFrustum = {
		{ 3.0, math.rad( 80.0 ), math.rad( 80.0 ) },
		{ 20.0, math.rad( 40.0 ), math.rad( 35.0 ) },
		{ 40.0, math.rad( 20.0 ), math.rad( 20.0 ) }
	}
	self.unit:setWhiskerData( 3, math.rad( 60.0 ), 1.5, 5.0 )
	self.noiseScale = 1.0
	self.impactCooldownTicks = 0
	
	self.isInCombat = false
	self.combatTimer = Timer()
	self.combatTimer:start( 40 * 12 )

	self.stateTicker = Ticker()
	self.stateTicker:init()
	
	-- Idle	
	self.idleState = self.unit:createState( "idle" )
	self.idleState.debugName = "idleState"
	
	-- Stagger
	self.staggeredEventState = self.unit:createState( "wait" )
	self.staggeredEventState.time = 0.25
	self.staggeredEventState.interruptible = false
	self.staggeredEventState.debugName = "staggeredEventState"
	self.stagger = 0.0
	self.staggerCooldownTicks = 0
	
	-- Roam
	self.roamTimer = Timer()
	self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
	self.roamState = self.unit:createState( "roam" )
	self.roamState.debugName = "roamState"
	self.roamState.tetherPosition = self.unit.character.worldPosition
	self.roamState.waterAvoidance = false
	self.roamState.roamCenterOffset = 0.0

	-- Pathing
	self.pathingState = PathingState()
	self.pathingState:sv_onCreate( self.unit )
	self.pathingState:sv_setTolerance( 1.0 )
	self.pathingState:sv_setMovementType( "sprint" )
	self.pathingState:sv_setWaterAvoidance( false )
	self.pathingState.debugName = "pathingState"
	
	-- Attacks
	self.attackState01 = self.unit:createState( "meleeAttack" )
	self.attackState01.meleeType = melee_totebotattack
	self.attackState01.event = "melee"
	self.attackState01.damage = 40
	self.attackState01.attackRange = 1.15
	self.attackState01.animationCooldown = 0.825 * 40
	self.attackState01.attackCooldown = 1.0 * 40
	self.attackState01.globalCooldown = 0.0 * 40
	self.attackState01.attackDelay = 0.25 * 40
	self.attackState01.power = 1000.0
	
	-- Combat
	self.combatAttackState = CombatAttackState()
	self.combatAttackState:sv_onCreate( self.unit )
	self.stateTicker:addState( self.combatAttackState )
	self.combatAttackState:sv_addAttack( self.attackState01 )
	self.combatAttackState.debugName = "combatAttackState"

	-- Breach
	self.breachState = BreachState()
	self.breachState:sv_onCreate( self.unit, math.ceil( 40 * 2.0 ) )
	self.stateTicker:addState( self.breachState )
	self.breachState:sv_setBreachRange( CombatAttackRange )
	self.breachState:sv_setBreachLevel( MeleeBreachLevel )
	self.breachState:sv_addAttack( self.attackState01 )
	self.breachState.debugName = "breachState"
	
	-- Combat approach
	self.combatApproachState = self.unit:createState( "positioning" )
	self.combatApproachState.debugName = "combatApproachState"
	self.combatApproachState.timeout = 0.5
	self.combatApproachState.tolerance = CombatAttackRange
	self.combatApproachState.avoidance = false
	self.combatApproachState.movementType = "sprint"
	self.combatApproachState.debugName = "combatApproachState"
	
	-- Avoid
	self.avoidState = self.unit:createState( "positioning" )
	self.avoidState.debugName = "avoid"
	self.avoidState.timeout = 1.5
	self.avoidState.tolerance = 0.5
	self.avoidState.avoidance = false
	self.avoidState.movementType = "sprint"
	self.avoidState.debugName = "avoidState"
	self.avoidCount = 0
	
	-- LookAt
	self.lookAtState = self.unit:createState( "positioning" )
	self.lookAtState.debugName = "lookAt"
	self.lookAtState.timeout = 3.0
	self.lookAtState.tolerance = 0.5
	self.lookAtState.avoidance = false
	self.lookAtState.movementType = "stand"

	-- Flee
	self.fleeState = self.unit:createState( "flee" )
	self.fleeState.movementAngleThreshold = math.rad( 180 )
	
	-- Tumble
	initTumble( self )
	
	-- Crushing
	initCrushing( self, DEFAULT_CRUSH_TICK_TIME )
	
	self.griefTimer = Timer()
	self.griefTimer:start( 40 * 9.0 )

	self.avoidResetTimer = Timer()
	self.avoidResetTimer:start( 40 * 16.0 )
	
	self.retreatpos = self.unit.character.worldPosition

	self.currentState = self.idleState
	self.currentState:start()
end

function SharkBotUnit.sv_flee( self )
	self.isInCombat = false
	self.eventTarget = nil
	if self.fleeFrom then
		self.currentState:stop()

		self.currentState = self.fleeState
		self.fleeState.fleeFrom = self.fleeFrom
		self.fleeState.maxFleeTime = math.random( FleeTimeMin, FleeTimeMax ) / 40
		self.fleeState.maxDeviation = 45 * math.pi / 180
		self.currentState:start()
	end
end

function SharkBotUnit:server_onRefresh()
	print( "-- SharkBotUnit refreshed --" )
end

function SharkBotUnit:server_onDestroy()
	print( "-- SharkBotUnit terminated --" )
end

--Raft
function SharkBotUnit:sv_raft_takeDamage( args )
	self:server_onMelee(args.hitPos, args.attacker, args.damage)
end
--Raft

function SharkBotUnit.server_onFixedUpdate( self, dt )
	if self.unit.character:isSwimming() then
		self.roamState.cliffAvoidance = true
		self.pathingState:sv_setCliffAvoidance( true )
		self.land = 0
		self.rayhit = sm.physics.raycast(self.unit.character.worldPosition,self.unit.character.worldPosition - sm.vec3.new(0,-4,0),{"terrainSurface"})
		if self.rayhit == nil then
			self.retreatpos = self.unit.character.worldPosition
			self.rayhit = nil
		else
			self.rayhit = nil
		end
	else
		self.land = self.land + 1
		if self.land > 3 then
			self.unit.character:setWorldPosition(self.retreatpos)
			if self.fleeFrom == nil and self.currentState ~= self.fleeState  then
				self.fleeFrom = self.unit.character.worldPosition + self.unit.character.direction
			end
		end
		self.roamState.cliffAvoidance = true
		self.pathingState:sv_setCliffAvoidance( true )
	end


	if self.currentState and self.currentState == self.fleeState then
		self.unit.character:setMovementSpeedFraction(fleeSpeed)

		--force shark to move because I don't get the ai shit
		if self.unit.character.velocity:length() < fleeSpeed*5 then
			sm.physics.applyImpulse(self.unit.character, self.unit.character.direction*500)
		end
	elseif self.unit.character:getMovementSpeedFraction() == fleeSpeed then
		self.unit.character:setMovementSpeedFraction(1)
	end

	self.stateTicker:tick()
	
	if updateCrushing( self ) then
		print("'SharkBotUnit' was crushed!")
		self:sv_onDeath( sm.vec3.new( 0, 0, 0 ) )
	end
	
	updateTumble( self )
	updateAirTumble( self, self.idleState )
	
	self.griefTimer:tick()
	
	if self.avoidCount > 0 then
		self.avoidResetTimer:tick()
		if self.avoidResetTimer:done() then
			self.avoidCount = 0
			self.avoidResetTimer:reset()
		end
	end
	
	if self.currentState then
		if self.target and not sm.exists( self.target ) then
			self.target = nil
		end

		-- Predict target velocity
		if self.target and type( self.target ) == "Character" then
			if self.predictedVelocity:length() > 0 and self.target:getVelocity():length() > self.predictedVelocity:length() then
				self.predictedVelocity = magicPositionInterpolation( self.predictedVelocity, self.target:getVelocity(), dt, 1.0 / 10.0 )
			else
				self.predictedVelocity = self.target:getVelocity()
			end
		else
			self.predictedVelocity = sm.vec3.new( 0, 0, 0 )
		end

		self.currentState:onFixedUpdate( dt )
		self.unit:setMovementDirection( self.currentState:getMovementDirection() )
		self.unit:setMovementType( self.currentState:getMovementType() )
		self.unit:setFacingDirection( self.currentState:getFacingDirection() )
		
		-- Random roaming during idle
		if self.currentState == self.idleState then
			self.roamTimer:tick()
		end

		if self.isInCombat then
			self.combatTimer:tick()
		end

		self.staggerCooldownTicks = math.max( self.staggerCooldownTicks - 1, 0 )
		self.impactCooldownTicks = math.max( self.impactCooldownTicks - 1, 0 )
		
	end
	
	-- Update target for totebot character
	if self.target ~= self.previousTarget then
		self:sv_updateCharacterTarget()
		self.previousTarget = self.target
	end
end

function SharkBotUnit.server_onCharacterChangedColor( self, color )
	if self.saved.color ~= color then
		self.saved.color = color
		self.storage:save( self.saved )
	end
end

function SharkBotUnit.server_onUnitUpdate( self, dt )
	if not sm.exists( self.unit ) then
		return
	end
	
	if self.currentState then
		self.currentState:onUnitUpdate( dt )
	end
	
	if self.unit.character:isTumbling() then
		return
	end
	
	local targetCharacter
	local closestVisiblePlayerCharacter
	local closestHeardPlayerCharacter
	local closestVisibleCrop
	local closestVisibleTeamOpponent
	if not SurvivalGame then
		closestVisibleTeamOpponent = sm.ai.getClosestVisibleTeamOpponent( self.unit, self.unit.character:getColor() )
	end
	closestVisiblePlayerCharacter = sm.ai.getClosestVisiblePlayerCharacter( self.unit )
	if not closestVisiblePlayerCharacter then
		closestHeardPlayerCharacter = ListenForPlayerNoise( self.unit.character, self.noiseScale )
	end
	if self.saved.raider then
		closestVisibleCrop = sm.ai.getClosestVisibleCrop( self.unit )
	elseif not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter then
		if self.griefTimer:done() then
			closestVisibleCrop = sm.ai.getClosestVisibleCrop( self.unit )
		end
	end

	-- Find target
	if closestVisiblePlayerCharacter then
		targetCharacter = closestVisiblePlayerCharacter
	elseif closestHeardPlayerCharacter then
		targetCharacter = closestHeardPlayerCharacter
	end
	
	-- Share found target
	local foundTarget = false
	if targetCharacter and self.target == nil and not self.fleeState == self.currentState then
		for _, allyUnit in ipairs( sm.unit.getAllUnits() ) do
			if sm.exists( allyUnit ) and self.unit ~= allyUnit and allyUnit.character and isAnyOf( allyUnit.character:getCharacterType(), g_robots ) and InSameWorld( self.unit, allyUnit) then
				if ( allyUnit.character.worldPosition - self.unit.character.worldPosition ):length() <= AllyRange then
					local sameTeam = true
					if not SurvivalGame then
						sameTeam = InSameTeam( allyUnit, self.unit )
					end
					if sameTeam then
						sm.event.sendToUnit( allyUnit, "sv_e_receiveTarget", { targetCharacter = targetCharacter, sendingUnit = self.unit } )
					end
				end
			end
		end
		foundTarget = true
	end
	
	-- Check for targets acquired from callbacks
	if self.eventTarget and sm.exists( self.eventTarget ) and targetCharacter == nil then
		if type( self.eventTarget ) == "Character" then
			if not ( self.eventTarget:isPlayer() and not sm.game.getEnableAggro() ) then
				targetCharacter = self.eventTarget
			end
		end
	end
	self.eventTarget = nil


	if targetCharacter then
		self.target = targetCharacter
	end

	if self.target and not sm.exists( self.target ) then
		self.target = nil
	end
	
	-- Cooldown after attacking a crop
	local _, attackResult = self.combatAttackState:isDone()
	if type( self.target ) == "Harvestable" then
		if attackResult == "started" or attackResult == "attacked" then
			self.griefTimer:reset()
		end
	elseif attackResult == "finished" then
		self.fleeFrom = self.target:getPlayer()
		sm.event.sendToPlayer(self.target:getPlayer(), "sv_e_tutorial", "shark")
	end
	
	if self.currentState == self.breachState then
		if self.BreachTimer < sm.game.getCurrentTick() then
			self.fleeFrom = self.target:getPlayer()
			sm.event.sendToPlayer(self.target:getPlayer(), "sv_e_tutorial", "shark")
			self:sv_flee( self.fleeFrom )
			prevState = self.currentState
			self.fleeFrom = nil
			print("stop breach")
		end
	else
		self.BreachTimer = 0
	end
	_, attackResult = self.breachState:isDone()
	if attackResult == "fail" or attackResult == "timeout" then
		self.fleeFrom = self.target:getPlayer()
		sm.event.sendToPlayer(self.target:getPlayer(), "sv_e_tutorial", "shark")
	end
	
	local inCombatApproachRange = false
	local inCombatAttackRange = false
	if self.target then
		self.lastTargetPosition = self.target.worldPosition
	end

	-- Check for positions acquired from noise
	local noiseShape = g_unitManager:sv_getClosestNoiseShape( self.unit.character.worldPosition, HearRange )
	if noiseShape and self.eventNoisePosition == nil then
		self.eventNoisePosition = noiseShape.worldPosition
	end
	local heardNoise = false
	if self.eventNoisePosition then
		self.lookAtState.desiredPosition = self.unit.character.worldPosition
		local fromToNoise = self.eventNoisePosition - self.unit.character.worldPosition
		fromToNoise.z = 0
		if fromToNoise:length() >= FLT_EPSILON then
			self.lookAtState.desiredDirection = fromToNoise:normalize()
		else
			self.lookAtState.desiredDirection = -self.unit.character.direction
		end
		heardNoise = true
	end
	self.eventNoisePosition = nil

	if self.lastTargetPosition then
		local fromToTarget = self.lastTargetPosition - self.unit.character.worldPosition
		local predictionScale = fromToTarget:length() / math.max( self.unit.character.velocity:length(), 1.0 )
		local predictedPosition = self.lastTargetPosition + self.predictedVelocity * predictionScale
		local desiredDirection = predictedPosition - self.unit.character.worldPosition
		local targetRadius = 0.0
		if self.target and type( self.target ) == "Character" then
			targetRadius = self.target:getRadius()
		end

		inCombatApproachRange = fromToTarget:length() - targetRadius <= CombatApproachRange
		inCombatAttackRange = fromToTarget:length() - targetRadius <= CombatAttackRange

		if fromToTarget:length() < rushRange then
			self.unit.character:setMovementSpeedFraction(attackSpeed)
		else
			self.unit.character:setMovementSpeedFraction(1)
		end

		local attackDirection = ( desiredDirection:length() >= FLT_EPSILON ) and desiredDirection:normalize() or self.unit.character.direction
		self.combatAttackState:sv_setAttackDirection( attackDirection ) -- Turn ongoing attacks toward moving players
		self.combatApproachState.desiredPosition = self.lastTargetPosition
		self.combatApproachState.desiredDirection = fromToTarget:normalize()
	end

	local prevState = self.currentState
	local prevInCombat = self.isInCombat
	if self.lastTargetPosition then
		self.isInCombat = true
		self.combatTimer:reset()
	end
	if self.combatTimer:done() then
		self.isInCombat = false
	end

	-- Check for direct path
	local directPath = false
	if self.lastTargetPosition then
		local directPathDistance = 7.0 
		local fromToTarget = self.lastTargetPosition - self.unit.character.worldPosition
		local distance = fromToTarget:length()
		if distance <= directPathDistance then
			directPath = sm.ai.directPathAvailable( self.unit, self.lastTargetPosition, directPathDistance )
		end
	end

	-- Update pathingState destination and condition
	local pathingConditions = { { variable = sm.pathfinder.conditionProperty.target, value = ( self.lastTargetPosition and 1 or 0 ) } }
	self.pathingState:sv_setConditions( pathingConditions )
	if self.currentState == self.pathingState then
		if self.target then
			local currentTargetPosition = self.target.worldPosition
			if type( self.target ) == "Harvestable" then
				currentTargetPosition = self.target.worldPosition + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			end
			self.pathingState:sv_setDestination( currentTargetPosition )
		elseif self.lastTargetPosition then
			self.pathingState:sv_setDestination( self.lastTargetPosition )
		end
	end

	-- Breach check
	local breachDestination
	if self.isInCombat and self.currentState ~= self.breachState then
		local nextTargetPosition
		if self.target then
			nextTargetPosition = self.target.worldPosition
		elseif self.lastTargetPosition then
			nextTargetPosition = self.lastTargetPosition
		end
		-- Always check for breachable in front of the unit
		if nextTargetPosition == nil then
			nextTargetPosition = self.unit.character.worldPosition + self.unit.character.direction
		end
		
		local breachDepth = 0.25
		local leveledNextTargetPosition = sm.vec3.new( nextTargetPosition.x, nextTargetPosition.y, self.unit.character.worldPosition.z )
		local valid, breachPosition, breachObject = sm.ai.getBreachablePosition( self.unit, leveledNextTargetPosition, breachDepth, MeleeBreachLevel )
		if valid and breachPosition then
			local flatFromToNextTarget = leveledNextTargetPosition
			flatFromToNextTarget.z = 0
			if flatFromToNextTarget:length() <= 0 then
				flatFromToNextTarget = sm.vec3.new( 0, 1, 0 )
			end
			breachDestination = nextTargetPosition + flatFromToNextTarget:normalize() * breachDepth
		end
	end

	-- Find dangerous obstacles
	local shouldAvoid = false
	local closestDangerShape, _ = g_unitManager:sv_shark_getClosestDangers( self.unit.character.worldPosition )
	if closestDangerShape then
		local fromToDanger = closestDangerShape.worldPosition - self.unit.character.worldPosition
		local distance = fromToDanger:length()
		if distance <= AvoidRange and ( ( self.target and self.avoidCount < AvoidLimit ) or self.target == nil ) then
			self.avoidState.desiredPosition = self.unit.character.worldPosition - fromToDanger:normalize() * 2
			self.avoidState.desiredDirection = fromToDanger:normalize()
			shouldAvoid = true
		end
	end

	local done, result = self.currentState:isDone()
	local abortState = 	( self.currentState ~= self.combatAttackState ) and
						( self.currentState ~= self.avoidState ) and
						(
							( shouldAvoid ) or
							( self.currentState == self.pathingState and ( inCombatApproachRange or inCombatAttackRange ) and self.isInCombat ) or
							( prevInCombat and self.combatTimer:done() ) or
							( self.currentState == self.pathingState and breachDestination ) or
							( self.currentState == self.breachState and directPath ) or
							( self.currentState == self.lookAtState and self.isInCombat ) or
							( self.currentState == self.roamState and heardNoise )
						)

	if ( done or abortState ) then
		-- Select state
		if self.fleeFrom then
			self:sv_flee( self.fleeFrom )
			prevState = self.currentState
			self.fleeFrom = nil
		elseif self.currentState == self.fleeState then
			self.currentState = self.idleState
		elseif shouldAvoid then
			-- Move away from danger
			if self.currentState ~= self.avoidState  then
				self.avoidCount = math.min( self.avoidCount + 1, AvoidLimit )
			end
			self.currentState = self.avoidState
		elseif breachDestination then
			-- Start breaching path obstacle
			self.breachState:sv_setDestination( breachDestination )
			self.currentState = self.breachState
			self.BreachTimer = sm.game.getCurrentTick() + BreachTime
		elseif self.currentState == self.pathingState and result == "failed" then
			self.avoidState.desiredDirection = self.unit.character.direction
			self.avoidState.desiredPosition = self.unit.character.worldPosition - self.avoidState.desiredDirection:normalize() * 2
			self.currentState = self.avoidState
		elseif self.isInCombat then
			-- Select combat state
			if self.target and inCombatAttackRange then
				-- Attack towards target character
				self.currentState = self.combatAttackState
			elseif self.target and inCombatApproachRange then
				-- Move close to the target to increase the likelihood of a hit
				self.currentState = self.combatApproachState
			elseif self.lastTargetPosition then
				if self.currentState ~= self.pathingState then
					self.pathingState:sv_setDestination( self.lastTargetPosition )
				else
					self.lastTargetPosition = nil
				end
				self.currentState = self.pathingState
			else
				-- Couldn't find the target
				self.isInCombat = false
			end
		else
			-- Select non-combat state
			if heardNoise then
				self.currentState = self.lookAtState
				self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
			elseif self.roamTimer:done() and not ( self.currentState == self.idleState and result == "started" ) then
				self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
				self.currentState = self.roamState
			elseif not ( self.currentState == self.roamState and result == "roaming" ) then
				self.currentState = self.idleState
			end
		end
	end

	if prevState ~= self.currentState then
		if ( prevState == self.roamState and self.currentState ~= self.idleState ) or ( prevState == self.idleState and self.currentState ~= self.roamState ) then
			self.unit:sendCharacterEvent( "alerted" )
		elseif self.currentState == self.idleState and prevState ~= self.roamState then
			self.unit:sendCharacterEvent( "roaming" )
		end
		
		prevState:stop()
		self.currentState:start()
		if DEBUG_AI_STATES then
			print( self.currentState.debugName )
		end
	end

	--move up or down
	if self.fleeState ~= self.currentState and (self.target and inCombatApproachRange) and not self.fleeFrom then
		if (self.currentState ~= self.combatApproachState) and (self.currentState ~= self.combatAttackState) and (self.currentState ~= self.breachState) then
			self.currentState = self.combatApproachState
		end

		unitZ = self.unit.character.worldPosition.z
		targetZ = self.target:getWorldPosition().z

		if unitZ < targetZ and unitZ < -3 then
			sm.physics.applyImpulse(self.unit.character, sm.vec3.new(0,0,1000))
		elseif unitZ > targetZ then
			sm.physics.applyImpulse(self.unit.character, sm.vec3.new(0,0,-1000))
		end
	end
end

function SharkBotUnit.sv_e_worldEvent( self, params )
	if sm.exists( self.unit ) and self.isInCombat == false then
		if params.eventName == "projectileHit" then
			if self.unit.character then
				local distanceToProjectile = ( self.unit.character.worldPosition - params.hitPos ):length()
				if distanceToProjectile <= 4.0 then
					if self.eventTarget == nil and params.attacker and params.attacker.character then
						self.eventTarget = params.attacker.character
					end
				end
			end
		elseif params.eventName == "projectileFire" then
			if self.unit.character then
				local distanceToShooter = ( self.unit.character.worldPosition - params.firePos ):length()
				if distanceToShooter <= 10.0 then
					if self.eventTarget == nil and params.attacker and params.attacker.character then
						self.eventTarget = params.attacker.character
					end
				end
			end
		elseif params.eventName == "collisionSound" then
			if self.unit.character then
				local soundReach = math.min( math.max( math.log( 1 + params.impactEnergy ) * 10.0, 0.0 ), 40.0 )
				local distanceToSound = ( self.unit.character.worldPosition - params.collisionPosition ):length()
				if distanceToSound <= soundReach then
					if self.eventNoisePosition == nil then
						self.eventNoisePosition = params.collisionPosition
					end
				end
			end
		end
	end
end

function SharkBotUnit.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end
	if damage > 0 then
		if self.fleeFrom == nil then
			self.fleeFrom = attacker
			self.unit:sendCharacterEvent( "hit" )
		end
	end

	local teamOpponent = false
	if type( attacker ) == "Unit" then
		if not SurvivalGame then
			teamOpponent = not InSameTeam( attacker, self.unit )
		end
	end

	if type( attacker ) == "Player" or type( attacker ) == "Shape" or teamOpponent then
		if damage > 0 then
			self:sv_addStagger( StaggerProjectile )
			if self.eventTarget == nil then
				if type( attacker ) == "Player" or type( attacker ) == "Unit" then
					self.eventTarget = attacker:getCharacter()
				elseif type( attacker ) == "Shape" then
					self.eventTarget = attacker
				end
			end
		end
		local impact = hitVelocity:normalize() * 6
		self:sv_takeDamage( damage, impact, hitPos )
	end
end

function SharkBotUnit.server_onMelee( self, hitPos, attacker, damage )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end
	local teamOpponent = false
	if type( attacker ) == "Unit" then
		if not SurvivalGame then
			teamOpponent = not InSameTeam( attacker, self.unit )
		end
	end

	if type( attacker ) == "Player" or teamOpponent then
		local attackingCharacter = attacker:getCharacter()
		if self.fleeFrom == nil then
			self.fleeFrom = attacker
			self.unit:sendCharacterEvent( "hit" )
		end


		self:sv_addStagger( StaggerMelee )
		if self.eventTarget == nil then
			self.eventTarget = attackingCharacter
		end
		
		local attackDirection = ( self.unit.character.worldPosition - attackingCharacter.worldPosition ):normalize()
		local impact = attackDirection * 6
		self:sv_takeDamage( damage, impact, hitPos )
	end
end

function SharkBotUnit.server_onExplosion( self, center, destructionLevel )
	if not sm.exists( self.unit ) then
		return
	end
	if self.fleeFrom == nil then
		self.fleeFrom = center
		self.unit:sendCharacterEvent( "hit" )
	end
	local impact = ( self.unit:getCharacter().worldPosition - center ):normalize() * 6
	self:sv_takeDamage( self.saved.stats.maxhp * ( destructionLevel / 10 ), impact, self.unit:getCharacter().worldPosition )
end

function SharkBotUnit.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if not sm.exists( self.unit ) then
		return
	end

	if type( other ) == "Character" then
		if not sm.exists( other ) then
			return
		end
		local teamOpponent = false
		if not SurvivalGame then
			teamOpponent = not InSameTeam( other, self.unit )
		end
		if other:isPlayer() or teamOpponent then
			if self.eventTarget == nil then
				self.eventTarget = other
			end
		end
	elseif type( other ) == "Shape" then
		if not sm.exists( other ) then
			return
		end
		if self.target == nil and self.eventTarget == nil then
			local creationBodies = other.body:getCreationBodies()
			for _, body in ipairs( creationBodies ) do
				local seatedCharacters = body:getAllSeatedCharacter()
				if #seatedCharacters > 0 then
					self.eventTarget = seatedCharacters[1]
					break
				end
			end
		end
	end
	
	if self.impactCooldownTicks > 0 then
		return
	end

	local collisionDamageMultiplier = 1.0
	local damage, tumbleTicks, tumbleVelocity, impactReaction = CharacterCollision( self.unit.character, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal, self.saved.stats.maxhp / collisionDamageMultiplier )
	damage = damage * collisionDamageMultiplier
	if damage > 0 or tumbleTicks > 0 then
		self.impactCooldownTicks = 6
	end
	if damage > 0 then
		print("'SharkBotUnit' took", damage, "collision damage")
		self:sv_takeDamage( damage, collisionNormal, collisionPosition )
	end
	if tumbleTicks > 0 then
		if startTumble( self, tumbleTicks, self.idleState, tumbleVelocity ) then
			if type( other ) == "Shape" and sm.exists( other ) and other.body:isDynamic() then
				sm.physics.applyImpulse( other.body, impactReaction * other.body.mass, true, collisionPosition - other.body.worldPosition )
			end
		end
	end
	
end

function SharkBotUnit.server_onCollisionCrush( self )
	if not sm.exists( self.unit ) then
		return
	end
	onCrush( self )
end

function SharkBotUnit.sv_updateCharacterTarget( self )
	if self.unit.character then
		sm.event.sendToCharacter( self.unit.character, "sv_n_updateTarget", { target = self.target } )
	end
end

function SharkBotUnit.sv_addStagger( self, stagger )
	
	-- Update stagger
	if self.staggerCooldownTicks <= 0 then
		self.staggerCooldownTicks = StaggerCooldownTickTime
		self.stagger = self.stagger + stagger
		local triggerStaggered = ( self.stagger >= 1.0 )
		self.stagger = math.fmod( self.stagger, 1.0 )

		if triggerStaggered then
			local prevState = self.currentState
			self.currentState = self.staggeredEventState
			prevState:stop()
			self.currentState:start()
		end
	end
	
end

function SharkBotUnit.sv_takeDamage( self, damage, impact, hitPos )
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		print( "'SharkBotUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )
		
		local effectRotation = sm.quat.identity()
		if hitPos and impact and impact:length() >= FLT_EPSILON then
			effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), -impact:normalize() )
		end
		sm.effect.playEffect( "ToteBot - Hit", hitPos, nil, effectRotation )

		if self.saved.stats.hp <= 0 then
			self:sv_onDeath( impact )
		else
			self.storage:save( self.saved )
		end
	end
end

function SharkBotUnit.sv_onDeath( self, impact )
	local character = self.unit:getCharacter()
	if not self.destroyed then
		sm.effect.playEffect( "ToteBot - DestroyedParts", character.worldPosition, nil, nil, nil, { Color = self.unit.character:getColor() } )
		g_unitManager:sv_addDeathMarker( character.worldPosition )
		self.saved.stats.hp = 0
		self.unit:destroy()
		print("'SharkBotUnit' killed!")
		if SurvivalGame then
			local loot = raft_SelectLoot( "loot_sharkbot" )
			raft_SpawnLoot( self.unit, loot )
		end
		self.destroyed = true
	end
end


function SharkBotUnit.sv_e_receiveTarget( self, params )
	if self.unit ~= params.unit then
		if self.eventTarget == nil then
			local sameTeam = false
			if not SurvivalGame then
				sameTeam = InSameTeam( params.targetCharacter, self.unit )
			end
			if not sameTeam then
				self.eventTarget = params.targetCharacter
			end
		end
	end
end

function SharkBotUnit:sv_e_onEnterWater() end

function SharkBotUnit:sv_e_onStayWater() end
