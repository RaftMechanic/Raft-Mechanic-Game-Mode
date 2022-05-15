dofile("$SURVIVAL_DATA/Scripts/game/survival_quests.lua")

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

function Antenna.server_completeQuest( self, character, state )
	g_questManager:sv_completeQuest(quest_radio_interactive)
    self.network:sendToClients("cl_playEffect")
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
        self.network:sendToServer("server_completeQuest")
	end
end

function Antenna.client_canInteract(self)
    return not g_questManager:cl_isQuestComplete(quest_radio_interactive)
end

function Antenna.cl_playEffect(self)
    self.effect:start()
end
