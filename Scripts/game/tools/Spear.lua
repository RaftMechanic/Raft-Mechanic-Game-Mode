
dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua" )

local Damage = 30

---@class Spear : ToolClass
---@field isLocal boolean
---@field animationsLoaded boolean
---@field equipped boolean
---@field swingCooldowns table
---@field fpAnimations table
---@field tpAnimations table
Spear = class()

local renderables = {
	"$CONTENT_DATA/Characters/Char_Tools/Char_spear/char_spear.rend"
}

local renderablesTp = {"$CONTENT_DATA/Characters/Char_Tools/Char_spear/char_male_tp_spear.rend", "$CONTENT_DATA/Characters/Char_Tools/Char_spear/char_spear_tp_animlist.rend"}
local renderablesFp = {"$CONTENT_DATA/Characters/Char_Tools/Char_spear/char_male_fp_spear.rend", "$CONTENT_DATA/Characters/Char_Tools/Char_spear/char_spear_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local Range = 5
local SwingStaminaSpend = 0.75

Spear.swingCount = 2
Spear.mayaFrameDuration = 1.0/30.0
Spear.freezeDuration = 0.075

Spear.swings = { "spear_attack1", "spear_attack2" }
Spear.swingFrames = { 4.2 * Spear.mayaFrameDuration, 4.2 * Spear.mayaFrameDuration }
Spear.swingExits = { "spear_exit1", "spear_exit2" }

function Spear.client_onCreate( self )
	self.isLocal = self.tool:isLocal()
	self:init()
end

function Spear.client_onRefresh( self )
	self:init()
	self:loadAnimations()
end

function Spear.init( self )
	
	self.attackCooldownTimer = 0.0
	self.freezeTimer = 0.0
	self.pendingRaycastFlag = false
	self.nextAttackFlag = false
	self.currentSwing = 1
	
	self.swingCooldowns = {}
	for i = 1, self.swingCount do
		self.swingCooldowns[i] = 0.0
	end
	
	self.dispersionFraction = 0.001
	
	self.blendTime = 0.2
	self.blendSpeed = 10.0
	
	self.sharedCooldown = 0.0
	self.hitCooldown = 1.0
	self.blockCooldown = 0.5
	self.swing = false
	self.block = false
	
	self.wantBlockSprint = false
	
	if self.animationsLoaded == nil then
		self.animationsLoaded = false
	end
end

function Spear.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			equip = { "spear_pickup", { nextAnimation = "idle" } },
			unequip = { "spear_putdown" },
			idle = {"spear_idle", { looping = true } },
			idleRelaxed = {"spear_idle_relaxed", { looping = true } },
			
			spear_attack1 = { "spear_attack1", { nextAnimation = "spear_exit1" } },
			spear_attack2 = { "spear_attack2", { nextAnimation = "spear_exit2" } },
			spear_exit1 = { "spear_exit1", { nextAnimation = "idle" } },
			spear_exit2 = { "spear_exit2", { nextAnimation = "idle" } },
			
			guardInto = { "spear_guard_into", { nextAnimation = "guardIdle" } },
			guardIdle = { "spear_guard_idle", { looping = true } },
			guardExit = { "spear_guard_exit", { nextAnimation = "idle" } },
			
			guardBreak = { "spear_guard_break", { nextAnimation = "idle" } }--,
			--guardHit = { "spear_guard_hit", { nextAnimation = "guardIdle" } }
			--guardHit is missing for tp
			
		
		}
	)
	local movementAnimations = {
		idle = "spear_idle",
		idleRelaxed = "spear_idle_relaxed",

		runFwd = "spear_run_fwd",
		runBwd = "spear_run_bwd",

		sprint = "spear_sprint",

		jump = "spear_jump",
		jumpUp = "spear_jump_up",
		jumpDown = "spear_jump_down",

		land = "spear_jump_land",
		landFwd = "spear_jump_land_fwd",
		landBwd = "spear_jump_land_bwd",

		crouchIdle = "spear_crouch_idle",
		crouchFwd = "spear_crouch_fwd",
		crouchBwd = "spear_crouch_bwd"
		
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spear_pickup", { nextAnimation = "idle" } },
				unequip = { "spear_putdown" },				
				idle = { "spear_idle",  { looping = true } },
				
				sprintInto = { "spear_sprint_into", { nextAnimation = "sprintIdle" } },
				sprintIdle = { "spear_sprint_idle", { looping = true } },
				sprintExit = { "spear_sprint_exit", { nextAnimation = "idle" } },
				
				spear_attack1 = { "spear_attack1", { nextAnimation = "spear_exit1" } },
				spear_attack2 = { "spear_attack2", { nextAnimation = "spear_exit2" } },
				spear_exit1 = { "spear_exit1", { nextAnimation = "idle" } },
				spear_exit2 = { "spear_exit2", { nextAnimation = "idle" } },
				
				guardInto = { "spear_guard_into", { nextAnimation = "guardIdle" } },
				guardIdle = { "spear_guard_idle", { looping = true } },
				guardExit = { "spear_guard_exit", { nextAnimation = "idle" } },
				
				guardBreak = { "spear_guard_break", { nextAnimation = "idle" } },
				guardHit = { "spear_guard_hit", { nextAnimation = "guardIdle" } }
			
			}
		)
		setFpAnimation( self.fpAnimations, "idle", 0.0 )
	end
	--self.swingCooldowns[1] = self.fpAnimations.animations["spear_attack1"].info.duration
	self.swingCooldowns[1] = 0.6
	--self.swingCooldowns[2] = self.fpAnimations.animations["spear_attack2"].info.duration
	self.swingCooldowns[2] = 0.6
	
	self.animationsLoaded = true

end

function Spear.client_onUpdate( self, dt )
	
	if not self.animationsLoaded then
		return
	end
	
	--synchronized update
	self.attackCooldownTimer = math.max( self.attackCooldownTimer - dt, 0.0 )

	--standard third person updateAnimation
	updateTpAnimations( self.tpAnimations, self.equipped, dt )
	
	--update
	if self.isLocal then
		
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			self:updateFreezeFrame(self.swings[self.currentSwing], dt)
		end
		
		local preAnimation = self.fpAnimations.currentAnimation

		updateFpAnimations( self.fpAnimations, self.equipped, dt )
		
		if preAnimation ~= self.fpAnimations.currentAnimation then
			
			-- Ended animation - re-evaluate what next state is
			
			local keepBlockSprint = false
			local endedSwing = preAnimation == self.swings[self.currentSwing] and self.fpAnimations.currentAnimation == self.swingExits[self.currentSwing]
			if self.nextAttackFlag == true and endedSwing == true then
				-- Ended swing with next attack flag
				
				-- Next swing
				self.currentSwing = self.currentSwing + 1
				if self.currentSwing > self.swingCount then
					self.currentSwing = 1
				end
				local params = { name = self.swings[self.currentSwing] }
				self.network:sendToServer( "server_startEvent", params )
				sm.audio.play( "Sledgehammer - Swing" )
				self.pendingRaycastFlag = true
				self.nextAttackFlag = false
				self.attackCooldownTimer = self.swingCooldowns[self.currentSwing]
				keepBlockSprint = true
				
			elseif isAnyOf( self.fpAnimations.currentAnimation, { "guardInto", "guardIdle", "guardExit", "guardBreak", "guardHit" } )  then
				keepBlockSprint = true
			end
			
			--Stop sprint blocking
			self.tool:setBlockSprint(keepBlockSprint)
		end
		
		local isSprinting =  self.tool:isSprinting() 
		if isSprinting and self.fpAnimations.currentAnimation == "idle" and self.attackCooldownTimer <= 0 and not isAnyOf( self.fpAnimations.currentAnimation, { "sprintInto", "sprintIdle" } ) then
			local params = { name = "sprintInto" }
			self:client_startLocalEvent( params )
		end
		
		if ( not isSprinting and isAnyOf( self.fpAnimations.currentAnimation, { "sprintInto", "sprintIdle" } ) ) and self.fpAnimations.currentAnimation ~= "sprintExit" then
			local params = { name = "sprintExit" }
			self:client_startLocalEvent( params )
		end
	end
	
end

function Spear.updateFreezeFrame( self, state, dt )
	local p = 1 - math.max( math.min( self.freezeTimer / self.freezeDuration, 1.0 ), 0.0 )
	local playRate = p * p * p * p
	self.fpAnimations.animations[state].playRate = playRate
	self.freezeTimer = math.max( self.freezeTimer - dt, 0.0 )
end

function Spear.server_startEvent( self, params )
	local player = self.tool:getOwner()
	if player then
		sm.event.sendToPlayer( player, "sv_e_staminaSpend", SwingStaminaSpend )
	end
	self.network:sendToClients( "client_startLocalEvent", params )
end

function Spear.client_startLocalEvent( self, params )
	self:client_handleEvent( params )
end

function Spear.client_handleEvent( self, params )
	
	-- Setup animation data on equip
	if params.name == "equip" then
		self.equipped = true
		--self:loadAnimations()
	elseif params.name == "unequip" then
		self.equipped = false
	end

	if not self.animationsLoaded then
		return
	end
	
	--Maybe not needed
-------------------------------------------------------------------
	
	-- Third person animations
	local tpAnimation = self.tpAnimations.animations[params.name]
	if tpAnimation then
		local isSwing = false
		for i = 1, self.swingCount do
			if self.swings[i] == params.name then
				self.tpAnimations.animations[self.swings[i]].playRate = 1
				isSwing = true
			end
		end
		
		local blend = not isSwing
		setTpAnimation( self.tpAnimations, params.name, blend and 0.2 or 0.0 )
	end
	
	-- First person animations
	if self.isLocal then
		local isSwing = false
		
		for i = 1, self.swingCount do
			if self.swings[i] == params.name then
				self.fpAnimations.animations[self.swings[i]].playRate = 1
				isSwing = true
			end
		end

		if isSwing or isAnyOf( params.name, { "guardInto", "guardIdle", "guardExit", "guardBreak", "guardHit" } ) then
			self.tool:setBlockSprint( true )
		else
			self.tool:setBlockSprint( false )
		end
		
		if params.name == "guardInto" then
			swapFpAnimation( self.fpAnimations, "guardExit", "guardInto", 0.2 )
		elseif params.name == "guardExit" then
			swapFpAnimation( self.fpAnimations, "guardInto", "guardExit", 0.2 )
		elseif params.name == "sprintInto" then
			swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.2 )
		elseif params.name == "sprintExit" then
			swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.2 )
		else
			local blend = not ( isSwing or isAnyOf( params.name, { "equip", "unequip" } ) )
			setFpAnimation( self.fpAnimations, params.name, blend and 0.2 or 0.0 )
		end
		
	end
		
end

--function Spear.sv_n_toggleTumble( self )
--	local character = self.tool:getOwner().character
--	character:setTumbling( not character:isTumbling() )
--end

function Spear.client_onEquippedUpdate( self, primaryState, secondaryState )
	--HACK Enter/exit tumble state when hammering
	--if primaryState == sm.tool.interactState.start then
	--	self.network:sendToServer( "sv_n_toggleTumble" )
	--end

	if self.pendingRaycastFlag then
		local time = 0.0
		local frameTime = 0.0
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			time = self.fpAnimations.animations[self.swings[self.currentSwing]].time
			frameTime = self.swingFrames[self.currentSwing]
		end
		if time >= frameTime and frameTime ~= 0 then
			self.pendingRaycastFlag = false
			local raycastStart = sm.localPlayer.getRaycastStart()
			local direction = sm.localPlayer.getDirection()
			sm.melee.meleeAttack( melee_sledgehammer, Damage, raycastStart, direction * Range, self.tool:getOwner() )
			local success, result = sm.localPlayer.getRaycast( Range, raycastStart, direction )
			if success then
				self.freezeTimer = self.freezeDuration
			end
		end
	end
	
	--Start attack?
	self.startedSwinging = ( self.startedSwinging or primaryState == sm.tool.interactState.start ) and primaryState ~= sm.tool.interactState.stop and primaryState ~= sm.tool.interactState.null
	if primaryState == sm.tool.interactState.start or ( primaryState == sm.tool.interactState.hold and self.startedSwinging ) then
		
		--Check if we are currently playing a swing
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			if self.attackCooldownTimer < 0.125 then
				self.nextAttackFlag = true
			end
		else
			--Not currently swinging
			--Is the prev attack done?
			if self.attackCooldownTimer <= 0 then
				self.currentSwing = 1
				--Not sprinting and not close to anything
				--Start swinging!
				local params = { name = self.swings[self.currentSwing] }
				self.network:sendToServer( "server_startEvent", params )
				sm.audio.play( "Sledgehammer - Swing" )
				self.pendingRaycastFlag = true
				self.nextAttackFlag = false
				self.attackCooldownTimer = self.swingCooldowns[self.currentSwing]
			end
		end
	end

	--Secondary destruction
	return true, false
	
end

function Spear.client_onEquip( self, animate )

	if animate then
		sm.audio.play( "Sledgehammer - Equip", self.tool:getPosition() )
	end

	self.equipped = true

	for k,v in pairs( renderables ) do renderablesTp[#renderablesTp+1] = v end
	for k,v in pairs( renderables ) do renderablesFp[#renderablesFp+1] = v end
	
	self.tool:setTpRenderables( renderablesTp )
	
	if self.isLocal then
		self.tool:setFpRenderables( renderablesFp )
	end

	self:init()
	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "equip", 0.0001 )

	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Spear.client_onUnequip( self, animate )

	self.equipped = false
	if sm.exists( self.tool ) then
		if animate then
			sm.audio.play( "Sledgehammer - Unequip", self.tool:getPosition() )
		end
		setTpAnimation( self.tpAnimations, "unequip" )
		if self.isLocal and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end
