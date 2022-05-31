dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")

RangerStationQuest = class()
RangerStationQuest.isSaveObject = true

local Stages = {
	read_log = 1,
	to_station = 2,
	find_battery = 3,
	activate_station = 4
}

function RangerStationQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.read_log
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.ReadLog, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.InventoryChanges, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.AreaTriggerEnter, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( "event.quest_mechanicstation.power_restored", self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function RangerStationQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
end

function RangerStationQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_rangerstation then
			self.sv.saved.completedStages[Stages.read_log] = true
		end
	elseif data.event == QuestEvent.InventoryChanges then
		-- Find master battery
		if FindInventoryChange( data.params.changes, obj_survivalobject_powercore ) > 0 then
			self.sv.saved.completedStages[Stages.find_battery] = true
		end
	elseif data.event == "event.quest_mechanicstation.power_restored" then
		-- Activate mechanic station
		self.sv.saved.completedStages[Stages.activate_station] = true
	end

	-- Detect player at the mechanic station for the first time
	if not self.sv.saved.completedStages[Stages.to_station] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_rangerstation" ) then
			self.sv.saved.completedStages[Stages.to_station] = true
		end
	end

	-- Detect already active mechanic station
	if not self.sv.saved.completedStages[Stages.activate_station] then
		local powercoreSockets = QuestEntityManager.Sv_GetInteractablesWithUuid( obj_survivalobject_powercoresocket )
		for _, powercoreSocket in pairs( powercoreSockets ) do
			if sm.exists( powercoreSocket ) and powercoreSocket.active and powercoreSocket.publicData and powercoreSocket.publicData.area == "mechanicstation" then
				self.sv.saved.completedStages[Stages.activate_station] = true
			end
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.to_station] then
		self.sv.saved.stage = Stages.to_station
	elseif not self.sv.saved.completedStages[Stages.find_battery] and not self.sv.saved.completedStages[Stages.activate_station] then
		self.sv.saved.stage = Stages.find_battery
	elseif not self.sv.saved.completedStages[Stages.activate_station] then
		self.sv.saved.stage = Stages.activate_station
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.to_station] and
		self.sv.saved.completedStages[Stages.activate_station] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_rangerstation" )
		QuestManager.Sv_TryActivateQuest( "quest_radio_interactive" )
	end

	self:sv_saveAndSync()
end


function RangerStationQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
	self.scriptableObject.clientPublicData.title = language_tag("Quest_RangerStation")
	self.scriptableObject.clientPublicData.isMainQuest = true
end

function RangerStationQuest.client_onRefresh( self )
end

function RangerStationQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_rangerstation.marker_battery", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_rangerstation.marker_socket", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.find_battery then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_rangerstation.marker_battery", true )

	elseif data.stage == Stages.activate_station then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_rangerstation.marker_socket", true )

	end

	self:cl_updateProgress( data.stage )
end

function RangerStationQuest.cl_updateProgress( self, stage )
	if stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RangerStation_Logbook")
	elseif stage == Stages.to_station then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RangerStation_Go_To")
	elseif isAnyOf( stage, { Stages.find_battery, Stages.activate_station } ) then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RangerStation_Activate")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
