-- Drill.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")

Drill = class( nil )

function Drill.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	local otherType = type( other )
	if ( otherType == "Harvestable" or otherType == "Shape" ) and sm.exists( other ) then
		local angularVelocity = self.shape.body.angularVelocity
		if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
			sm.physics.applyImpulse( self.shape, sm.vec3.new( 0, self.shape.mass * 0.25, 0 ), false )
		end
	end
end

function Drill.client_onCreate( self )
	self.drillEffect = sm.effect.createEffect( "Drill - StoneDrill", self.interactable )
	self.stoneEffect = sm.effect.createEffect( "Stone - Stress" )
	self.remainingDrillTicks = 0
	self.remainingImpactTicks = 0
end

function Drill.client_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	local angularVelocity = self.shape.body.angularVelocity
	if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
		local otherType = type( other )
		local mass = 250
		local materialId = 0
		if ( otherType == "Harvestable" or otherType == "Shape" ) and sm.exists( other ) then
			materialId = other.materialId
			if otherType == "Shape" then
				mass = other.mass
			end
		end
	
		if not sm.isHost then
			sm.physics.applyImpulse( self.shape, sm.vec3.new( 0, self.shape.mass * 0.25, 0 ), false )
		end
		direction = ( selfPointVelocity + otherPointVelocity ):normalize()

		self.stoneEffect:setPosition( collisionPosition )
		self.stoneEffect:setParameter( "size", mass / AUDIO_MASS_DIVIDE_RATIO )
		self.stoneEffect:setParameter( "velocity_max_50", angularVelocity:length() )
		self:cl_triggerEffect( collisionPosition, direction, materialId )
	end
end

-- Client

function Drill.cl_triggerEffect( self, position, direction, materialId )
	local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), direction )
	sm.effect.playEffect( "Drill - Debris", position, nil, rotation, nil, { drill_material = materialId } )
	
	self.remainingImpactTicks = 60
	if materialId == 6 then -- Drilling stone
		self.remainingDrillTicks = 5
	end
end

function Drill.client_onFixedUpdate( self, deltaTime )

	local velocity = self.shape:getBody():getAngularVelocity():length()
	if self.remainingImpactTicks > 0 then
		self.drillEffect:setParameter( "impact", 1 )		
		self.remainingImpactTicks = self.remainingImpactTicks - 1
	else
		self.drillEffect:setParameter( "impact", 0 )
	end

	if self.remainingDrillTicks > 0 then
		if not self.stoneEffect:isPlaying() then
			self.stoneEffect:start()
		end
		self.remainingDrillTicks = self.remainingDrillTicks - 1
	else
		if self.stoneEffect:isPlaying() then
			self.stoneEffect:stop()
		end
	end
	
	local effectVelocity = clamp( velocity, 0, 50 ) / 50
	self.drillEffect:setParameter( "velocity", effectVelocity )
	
	if velocity > 0 then
		if self.drillEffect:isPlaying() == false then
			self.drillEffect:start()
		end
	else
		if self.drillEffect:isPlaying() == true then
			self.drillEffect:stop()
		end
	end
	
end

--Raft
STONES = {
	obj_harvests_stones_p01,
	obj_harvests_stones_p02,
	obj_harvests_stones_p03,
	obj_harvests_stones_p04,
	obj_harvests_stones_p05,
	obj_harvests_stones_p06,
	obj_harvest_stonechunk01,
	obj_harvest_stonechunk02,
	obj_harvest_stonechunk03
}

function Drill:cl_triggerEffects(params)
	local angularVelocity = params.angularVelocity
	local mass = 250

	pos = self.shape:getWorldPosition() + self.shape.at*0.3
	self.stoneEffect:setPosition( pos )
	self.stoneEffect:setParameter( "size", mass / AUDIO_MASS_DIVIDE_RATIO )
	self.stoneEffect:setParameter( "velocity_max_50", angularVelocity:length() )
	self:cl_triggerEffect( pos, -self.shape.at, params.materialId )
end

function Drill:server_onFixedUpdate()
	local angularVelocity = self.shape.body.angularVelocity
	if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
		local radius = 0.4

		--break harvestable into stone chunks
		for _, harvestable in ipairs(sm.physics.getSphereContacts(self.shape:getWorldPosition(), radius).harvestables) do
			materialId = harvestable.materialId
			self.network:sendToClients( "cl_triggerEffects", {materialId = materialId, angularVelocity = angularVelocity} )

			if materialId ~= 6 then return end
			
			damage = math.min( 2.5, angularVelocity:length() )
			position = self.shape:getWorldPosition()
			harvestable:setPublicData({damage = damage, position = position})
		end

		--look for stone chunks
		for _, body in ipairs(sm.physics.getSphereContacts(self.shape:getWorldPosition(), radius).bodies) do
			for __, shape in ipairs(body:getShapes()) do	
				uuid = shape:getShapeUuid()
				for ___, stoneUuid in ipairs(STONES) do
					if uuid == stoneUuid then
						materialId = shape:getMaterialId()
						self.network:sendToClients( "cl_triggerEffects", {materialId = materialId, angularVelocity = angularVelocity} )						
						
						damage = math.min( 2.5, angularVelocity:length() )
						shape:getInteractable():setPublicData({damage = damage})
						return
					end
				end
			end
		end
	end
end