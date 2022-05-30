dofile("$CONTENT_DATA/Scripts/game/managers/QuestManager.lua")

Antenna = class()
Antenna.maxParentCount = 0
Antenna.maxChildCount = 0
Antenna.connectionInput = sm.interactable.connectionType.none
Antenna.connectionOutput = sm.interactable.connectionType.none
Antenna.poseWeightCount = 1

local UVSpeed = 5
local UnfoldSpeed = 15

function Antenna:server_onCreate()
	self.sv = {}
	self.sv.loaded = true
	self.sv.iconData = {
		iconIndex = 0,
		colorIndex = 1
	}

	self.network:setClientData( { iconIndex = self.sv.iconData.iconIndex, colorIndex = self.sv.iconData.colorIndex } )

	if g_beaconManager then
		g_beaconManager:sv_createBeacon( self.shape, self.sv.iconData )
	end
end

function Antenna.server_onDestroy( self )
	if self.sv.loaded then
		if g_beaconManager then
			g_beaconManager:sv_destroyBeacon( self.shape )
		end
		self.sv.loaded = false
	end
end

function Antenna.server_onUnload( self )
	if self.sv.loaded then
		if g_beaconManager then
			g_beaconManager:sv_unloadBeacon( self.shape )
		end
		self.sv.loaded = false
	end
end

function Antenna.client_onCreate( self )
    self.cl = {}
	self.cl.iconData = {
		iconIndex = 0,
		colorIndex = 1
	}

	self.cl.loopingIndex = 0
	self.cl.unfoldWeight = 0
	self.effect = sm.effect.createEffect( "Antenna - Activation", self.interactable )
end

function Antenna.client_onUpdate( self, dt )
	self.cl.loopingIndex = self.cl.loopingIndex + dt * UVSpeed
	if self.cl.loopingIndex >= 4 then
		self.cl.loopingIndex = 0
	end
	self.interactable:setUvFrameIndex( math.floor( self.cl.loopingIndex ) )

	if self.cl.unfoldWeight < 1.0 then
		self.cl.unfoldWeight = math.min( self.cl.unfoldWeight + dt * UnfoldSpeed, 1.0 )
		self.interactable:setPoseWeight( 0, self.cl.unfoldWeight )
	end

	if self.cl.idleSound and not self.cl.idleSound:isPlaying() then
		self.cl.idleSound:start()
	end
end

function Antenna.client_onInteract( self, character, state )
	if state == true then
        self.network:sendToServer("sv_send_event")
	end
end

function Antenna:sv_send_event()
	self.network:sendToClients("cl_playEffect")
	QuestManager.Sv_OnEvent(QuestEvent.Antenna)
end

function Antenna.client_canInteract(self)
	if not QuestManager.Cl_IsQuestComplete("quest_radio_interactive") then
    	local keyBindingText = sm.gui.getKeyBinding( "Use", true )
    	sm.gui.setInteractionText("", keyBindingText, language_tag("AntennaInteract"))
		return true
	end
	return false
end

function Antenna.cl_playEffect(self)
    self.effect:start()
end