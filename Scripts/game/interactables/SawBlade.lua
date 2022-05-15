-- SawBlade.lua --

SawBlade = class( nil )

--RAFT start
local radius = 1.0
--RAFT end

function SawBlade.client_onCreate( self )
	self.sawEffect = sm.effect.createEffect( "Saw - SawBlade", self.interactable )
	self.remainingImpactTicks = 0
end

function SawBlade.client_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	local otherType = type( other )
	local materialId = 0
	if ( otherType == "Harvestable" or otherType == "Shape" ) and sm.exists( other ) then
		materialId = other.materialId
	end
		
	local angularVelocity = self.shape.body.angularVelocity
	if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
		local direction = ( selfPointVelocity + otherPointVelocity ):normalize()
		self:cl_triggerEffect( collisionPosition, direction, materialId )
	end
end

-- Client

function SawBlade.cl_triggerEffect( self, position, direction, materialId )
	local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), direction )
	sm.effect.playEffect( "Saw - Debris", position, nil, rotation, nil, { saw_material = materialId } )
	
	self.remainingImpactTicks = 60
end

function SawBlade.client_onFixedUpdate( self, deltaTime )

	local velocity = self.shape:getBody():getAngularVelocity():length()
	if self.remainingImpactTicks > 0 then
		self.sawEffect:setParameter( "impact", 1 )		
		self.remainingImpactTicks = self.remainingImpactTicks - 1
	else
		self.sawEffect:setParameter( "impact", 0 )
	end
	
	local effectVelocity = clamp( velocity, 0, 50 ) / 50
	self.sawEffect:setParameter( "velocity", effectVelocity )
	
	if velocity > 0 then
		if self.sawEffect:isPlaying() == false then
			self.sawEffect:start()
		end
	else
		if self.sawEffect:isPlaying() == true then
			self.sawEffect:stop()
		end
	end
	
end



--Raft
function SawBlade:cl_triggerEffects(params)
	local angularVelocity = params.angularVelocity
	local mass = 250

	pos = self.shape:getWorldPosition() + self.shape.at*0.3
	self.sawEffect:setParameter( "size", mass / AUDIO_MASS_DIVIDE_RATIO )
	self.sawEffect:setParameter( "velocity", clamp( self.shape:getBody():getAngularVelocity():length(), 0, 50 ) / 50 )
	self:cl_triggerEffect( pos, self.shape.up, params.materialId )
end

function SawBlade:server_onCreate()
	self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, sm.vec3.new(0.25,radius,radius), sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.harvestable)
end

function SawBlade:server_onFixedUpdate()
	local angularVelocity = self.shape.body.angularVelocity
	if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
		local harvestables = {}
		for _, harvestable in ipairs(self.trigger:getContents()) do
			table.insert(harvestables, harvestable.id)
		end

		--break harvestable into tree trunks
		for _, harvestable in ipairs(sm.physics.getSphereContacts(self.shape:getWorldPosition(), radius).harvestables) do
			local materialId = harvestable.materialId
			if materialId ~= 7 then return end

			--only if areatrigger and sphere overlap, aka cylinder collision (something like that)
			for _, id in ipairs(harvestables) do
				if harvestable.id == id then
					self.network:sendToClients( "cl_triggerEffects", {materialId = materialId, angularVelocity = angularVelocity} )
			
					damage = math.min( 2.5, angularVelocity:length() )
					position = self.shape:getWorldPosition()
					harvestable:setPublicData({damage = damage, position = position})
				end
			end
		end
	end
end