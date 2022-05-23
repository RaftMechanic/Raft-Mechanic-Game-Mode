dofile "$SURVIVAL_DATA/Scripts/game/characters/BaseCharacter.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"
dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )

SharkBotCharacter = class( nil )

local CONTENT_DATA = "$CONTENT_667b4c22-cc1a-4a2b-bee8-66a6c748d40e"

function SharkBotCharacter.client_onCreate( self )
	self.animations = {}
	print( "-- SharkBotCharacter created --" )
	self:client_onRefresh()
end

function SharkBotCharacter.client_onDestroy( self )
	print( "-- SharkBotCharacter destroyed --" )
end

function SharkBotCharacter.client_onRefresh( self )
	print( "-- SharkBotCharacter refreshed --" )
end

function SharkBotCharacter.client_onEvent( self, event )
	if not self.animationsLoaded then
		return
	end
	if self.graphicsLoaded then
		if event == "attack" then
			self.currentAnimation = "attack"
			self.animations.attack.time = 0
			sm.effect.playHostedEffect( "Watercannon - Impact",self.character, "jnt_head")
		elseif event == "ground_a" and self.currentAnimation ~= "ground_a" then
			self.currentAnimation = "ground_a"
			self.animations.ground_a.time = 0
			sm.effect.playHostedEffect( "Water - WaterProjectileTrail",self.character, "jnt_tailtop")
		elseif event == "raft" then
			sm.audio.play( "RaftShark", self.character:getWorldPosition() )
		end
	end

end

function SharkBotCharacter.client_onUpdate(self, dt )
	if sm.exists(self.character) then
		for name, animation in pairs(self.animations) do
			animation.time = animation.time + dt
			if name == self.currentAnimation then
				animation.weight = math.min(animation.weight+(self.blendSpeed * dt), 1.0)
				if animation.time >= animation.info.duration then
					self.currentAnimation = ""
				end
			else
				animation.weight = math.max(animation.weight-(self.blendSpeed * dt ), 0.0)
			end
			self.character:updateAnimation( animation.info.name, animation.time, animation.weight )
		end

	end
end


function SharkBotCharacter.client_onGraphicsLoaded( self )

	self.animations.attack = {
		info = self.character:getAnimationInfo( "attack" ),
		time = 0,
		weight = 0
	}
	
	self.animations.ground_a = {
		info = self.character:getAnimationInfo( "ground_a" ),
		time = 0,
		weight = 0
	}
	self.animationsLoaded = true

	self.blendSpeed = 5.0
	self.blendTime = 0.2
	
	self.currentAnimation = ""
	
	self.character:setMovementEffects( CONTENT_DATA.."/Characters/Char_sharkbot/movement_effects.json" )
	self.graphicsLoaded = true
end

function SharkBotCharacter.client_onGraphicsUnloaded( self ) 
	self.graphicsLoaded = false
end