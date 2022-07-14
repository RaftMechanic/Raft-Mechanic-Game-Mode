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
g_sleepers = g_sleepers or {}

function Hammock:server_onCreate()
	Bed.server_onCreate(self)

	self.id = #g_sleepers + 1
	g_sleepers[self.id] = self.shape

	self.skip = {
		active = false,
		sleeping = false,
		tick = 0
	}
end

function Hammock:server_onDestroy()
	g_sleepers[self.id] = nil
end

function Hammock:sv_activateBed( character )
	Bed.sv_activateBed(self, character)
	QuestManager.Sv_OnEvent(QuestEvent.Sleep, {character = character})
end

function Hammock:server_onFixedUpdate( dt )
	Bed.server_onFixedUpdate(self)

	local time = sm.storage.load( STORAGE_CHANNEL_TIME )
	local night = time.timeOfDay > 0.85 or time.timeOfDay < 0.175

	if not night then return end

	--only the first bed in the table does stuff
	for _, check in pairs(g_sleepers) do
		if check ~= nil and self.shape ~= check then break end

		--print("first hammock did stuff!", self.shape.id, #g_sleepers)
		if not self.skip.active then
			if self:getSleepingPeople() == #sm.player.getAllPlayers() then
				self.skip.active = true
				self.skip.tick = sm.game.getCurrentTick() + sleepTime
			end
		elseif sm.game.getCurrentTick() >= self.skip.tick then
			if not self.skip.sleeping then
				self.skip.sleeping = true
				self.skip.tick = sm.game.getCurrentTick() + 40
				self.network:sendToClients("cl_sleep")
				return
			end

			sm.event.sendToGame("sv_setTimeOfDay", 0.175+0.001)
			self.skip.active = false
			self.skip.tick = 0
			self.skip.sleeping = false
		end
	end
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

function Hammock:client_canInteract()
	local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"

	local time = sm.game.getTimeOfDay()
	local night = time > 0.85 or time < 0.175
	if not night then
		sm.gui.setInteractionText(o1..language_tag("HammockNight")..o2)
	end

	return true
end

function Hammock:client_onInteract( character, state )
	Bed.client_onInteract(self, character, state)
	if state == true then
		sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_tutorial", "sleep")
		if self:getSleepingPeople() + 1 ~= #sm.player.getAllPlayers() then
			sm.gui.displayAlertText(language_tag("HammockAllPlayers"))
		end
	end
end

function Hammock:getSleepingPeople()
	local sleepingPeople = 0
	for k, player in pairs(sm.player.getAllPlayers()) do
		local char = player.character
		if sm.exists(char) then
			local lockingInt = char:getLockingInteractable()
			if lockingInt ~= nil and lockingInt.shape.uuid == obj_hammock then
				sleepingPeople = sleepingPeople + 1
			end
		end
	end

	return sleepingPeople
end

function Hammock:client_onAction( controllerAction, state )
	local time = sm.game.getTimeOfDay()
	local night = time > 0.85 or time < 0.175
	if night and self:getSleepingPeople() == #sm.player.getAllPlayers() then return true end

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