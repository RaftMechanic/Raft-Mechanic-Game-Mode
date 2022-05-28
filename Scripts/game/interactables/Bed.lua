-- Bed.lua --

Bed = class( nil )

function Bed.server_onDestroy( self )
	if self.loaded then
		g_respawnManager:sv_destroyBed( self.shape )
		self.loaded = false
	end
end

function Bed.server_onUnload( self )
	if self.loaded then
		g_respawnManager:sv_updateBed( self.shape )
		self.loaded = false
	end
end

function Bed.sv_activateBed( self, character )
	g_respawnManager:sv_registerBed( self.shape, character )
end

function Bed.server_onCreate( self )
	self.loaded = true
end

function Bed.server_onFixedUpdate( self )
	local prevWorld = self.currentWorld
	self.currentWorld = self.shape.body:getWorld()
	if prevWorld ~= nil and self.currentWorld ~= prevWorld then
		g_respawnManager:sv_updateBed( self.shape )
	end
end

-- Client

function Bed.client_onInteract( self, character, state )
	if state == true then
		if self.shape.body:getWorld().id > 1 then
			sm.gui.displayAlertText( "#{INFO_HOME_NOT_STORED}" )
		else
			self.network:sendToServer( "sv_activateBed", character )
			self:cl_seat()
			sm.gui.displayAlertText( "#{INFO_HOME_STORED}" )
		end
	end
end

function Bed.cl_seat( self )
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end

function Bed.client_onAction( self, controllerAction, state )
	local consumeAction = true
	if state == true then
		if controllerAction == sm.interactable.actions.use or controllerAction == sm.interactable.actions.jump then
			self:cl_seat()
		else
			consumeAction = false
		end
	else
		consumeAction = false
	end
	return consumeAction
end

--RAFT
dofile("$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua")
dofile("$CONTENT_DATA/Scripts/game/raft_quests.lua")
dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )

Hammock = class(Bed)

local sleepTime = 40*5 --ticks

function Hammock:server_onCreate()
	Bed.server_onCreate(self)

	if not g_sleepers then
		g_sleepers = {}
		g_sleepers.update = sm.game.getCurrentTick()
	end
end
function Hammock:sv_activateBed( character )
	Bed.sv_activateBed(self, character)
	QuestManager.Sv_OnEvent(QuestEvent.Sleep, {character = character})
end


function Hammock:server_onFixedUpdate( dt )
	Bed.server_onFixedUpdate(self)

	if g_sleepers.update < sm.game.getCurrentTick() then
		g_sleepers.update = sm.game.getCurrentTick()

		if g_sleepers.skipNight then
			if g_sleepers.skipNight < sm.game.getCurrentTick() then
				sm.event.sendToGame("sv_setTimeOfDay", 0.175+0.001)
				g_sleepers.skipNight = false
			end
			return
		end

		local time = sm.storage.load( STORAGE_CHANNEL_TIME )
		local night = time.timeOfDay > 0.85 or time.timeOfDay < 0.175

		for _, player in ipairs(sm.player.getAllPlayers()) do
			local char = player:getCharacter()
			if char then
				local interactable = char:getLockingInteractable()
				if interactable and interactable.shape.uuid == self.shape.uuid and g_sleepers[player.id] then
					g_sleepers[player.id].ticks = g_sleepers[player.id].ticks + 1
				else
					g_sleepers[player.id] = {ticks = 0, player = player}
				end
			end
		end

		local sleeping = 0
		for id, sleep in ipairs(g_sleepers) do
			if sleep.ticks == sleepTime then
				self.network:sendToClient(sleep.player, "cl_show_message", not night and "HammockNight" or "HammockAllPlayers")
			elseif sleep.ticks > sleepTime then
				sleeping = sleeping + 1
			end
		end

		if night and sleeping == #sm.player.getAllPlayers() then
			self.network:sendToClients("cl_sleep")
			g_sleepers.skipNight = sm.game.getCurrentTick() + 40
		end
	end
end

function Hammock:cl_show_message(tag)
	sm.gui.displayAlertText(language_tag(tag))
end

function Hammock:cl_sleep()
	sm.event.sendToPlayer( sm.localPlayer.getPlayer(), "cl_e_startFadeToBlack", { duration = 1.0, timeout = 3.0 } )
end

function Hammock:client_onFixedUpdate(dt)
	if g_questManager:cl_getQuestProgressString("quest_raft_tutorial") == language_tag("Quest_Tutorial_Sleep") then 
		if not self.questMarkerGui then
			self.questMarkerGui = sm.gui.createWorldIconGui( 60, 60, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
			self.questMarkerGui:setImage( "Icon", "icon_questmarker.png" )
			self.questMarkerGui:setRequireLineOfSight( false )
			self.questMarkerGui:setMaxRenderDistance( 10000 )
			self.questMarkerGui:setHost(self.shape)
			self.questMarkerGui:open()
		end
	elseif self.questMarkerGui then
		self.questMarkerGui:close()
		self.questMarkerGui = nil
	end
end