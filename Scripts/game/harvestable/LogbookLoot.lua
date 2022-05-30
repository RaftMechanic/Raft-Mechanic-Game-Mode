-- LogbookLoot.lua --
dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )

LogbookLoot = class( nil )

local OpeningTickTime = 10
local STATE_CLOSED = 0
local STATE_OPENING = 1
local STATE_OPEN = 2

function LogbookLoot.server_onCreate( self )
	self.sv = {}
	self.sv.state = STATE_CLOSED
	self.sv.openingTicks = 0
	self.network:setClientData( { state = self.sv.state } )
end

function LogbookLoot.server_canErase( self ) return self.sv.state == STATE_OPEN end
function LogbookLoot.client_canErase( self ) return self.cl.state == STATE_OPEN end

function LogbookLoot.server_onRemoved( self, player )
	self:sv_n_pickup( { state = self.sv.state }, player )
end

function LogbookLoot.sv_n_pickup( self, params, player )
	if self.sv.state == STATE_OPEN and params.state == STATE_OPEN then
		if not self.sv.removed then
			sm.event.sendToPlayer( player, "sv_e_onLoot", { name = "#{MENU_OPTIONS_CONTROLS_LOGBOOK}", pos = self.harvestable:getPosition(), effectName = "Loot - LogfilesPickup" } )
			self.sv.removed = true
			QuestManager.Sv_OnEvent(QuestEvent.TraderNotes)
			sm.harvestable.destroy( self.harvestable )
		end
	elseif self.sv.state == STATE_CLOSED then
		self.sv.openingTicks = OpeningTickTime
		self.sv.state = STATE_OPENING
		self.network:setClientData( { state = self.sv.state } )
	end
end

function LogbookLoot.server_onFixedUpdate( self, timeStep )
	if self.sv.openingTicks > 0 then
		self.sv.openingTicks = self.sv.openingTicks - 1
		if self.sv.openingTicks <= 0 then
			self.sv.openingTicks = 0
			self.sv.state = STATE_OPEN
			self.network:setClientData( { state = self.sv.state } )
		end
	end
end

function LogbookLoot.client_onCreate( self )
	-- Create the renderable effect with a random starting rotation
	self.cl = {}
	self.cl.state = STATE_CLOSED

	self.cl.logbookEffect = sm.effect.createEffect( "Loot - Logbook" )
	self.cl.entryActivateEffect = sm.effect.createEffect( "Loot - Logentryactivate" )
	self.cl.entryEffect = sm.effect.createEffect( "Loot - Logentry" )
	local forward = sm.vec3.new( 0, 1, 0 )
	self.cl.rotation = math.random() * math.pi * 2
	local effectPosition = self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.375 )
	self.cl.logbookEffect:setRotation( sm.vec3.getRotation( forward, forward:rotateZ( self.cl.rotation ) ) )
	self.cl.logbookEffect:setPosition( effectPosition )
	self.cl.logbookEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
	self.cl.entryActivateEffect:setPosition( effectPosition )
	self.cl.entryEffect:setPosition( effectPosition )
end

function LogbookLoot.client_onClientDataUpdate( self, clientData )
	if self.cl == nil then
		self.cl = {}
	end
	self.cl.state = clientData.state
end

function LogbookLoot.client_onDestroy( self )
	self.cl.logbookEffect:stop()
	self.cl.logbookEffect:destroy()
	self.cl.entryEffect:stop()
	self.cl.entryEffect:destroy()
	self.cl.entryActivateEffect:stop()
	self.cl.entryActivateEffect:destroy()
end

function LogbookLoot.client_onUpdate( self, dt )
	if self.cl.state == STATE_OPEN then
		if not self.cl.logbookEffect:isPlaying() then
			self.cl.logbookEffect:start()
		end
		if self.cl.entryEffect:isPlaying() then
			self.cl.entryActivateEffect:start()
			self.cl.entryEffect:stop()
		end

		-- Slowly rotate the effect
		local rotationSpeed = 0.1875 -- Revolutions per second
		self.cl.rotation = math.fmod( self.cl.rotation + math.pi * 2 * dt * rotationSpeed, math.pi * 2 )
		local forward = sm.vec3.new( 0, 1, 0 )
		self.cl.logbookEffect:setRotation( sm.vec3.getRotation( forward, forward:rotateZ( self.cl.rotation ) ) )
	elseif self.cl.state == STATE_OPENING then
		if self.cl.entryEffect:isPlaying() then
			self.cl.entryActivateEffect:start()
			self.cl.entryEffect:stop()
		end
	elseif self.cl.state == STATE_CLOSED then
		if not self.cl.entryEffect:isPlaying() then
			self.cl.entryEffect:start()
		end
		if self.cl.logbookEffect:isPlaying() then
			self.cl.logbookEffect:stop()
		end
	else
		if self.cl.entryEffect:isPlaying() then
			self.cl.entryEffect:stop()
		end
		if self.cl.logbookEffect:isPlaying() then
			self.cl.logbookEffect:stop()
		end
	end
end

function LogbookLoot.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer( "sv_n_pickup", { state = self.cl.state } )
	end
end

function LogbookLoot.client_canInteract( self ) 
	if not (QuestManager.cl_getQuestProgressString(g_questManager, "quest_radio_location") == language_tag("Quest_RadioSignal_ExploreWreck")) then
		sm.gui.setInteractionText("", "", language_tag("QuestItemTooEarly"))
		return false
	end

	if self.cl.state == STATE_CLOSED then
		local keyBindingText = sm.gui.getKeyBinding( "Use", true )
    	sm.gui.setInteractionText("", keyBindingText, "#{INTERACTION_USE}")
	elseif self.cl.state == STATE_OPENING then
		return false
	elseif self.cl.state == STATE_OPEN then
		sm.gui.setCenterIcon( "Use" )
		local keyBindingText =  sm.gui.getKeyBinding( "Attack", true )
		sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_PICK_UP} [" .. "#{MENU_OPTIONS_CONTROLS_LOGBOOK}" .. "]" )
	end
	return true
end