dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

DeliverVegetablesQuest = class()
DeliverVegetablesQuest.isSaveObject = true

local Stages = {
	read_log = 1,
	reach_station = 2,
	suck_crates = 3
}

function DeliverVegetablesQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.read_log
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.ReadLog, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.AreaTriggerEnter, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.Vegetables, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function DeliverVegetablesQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
end

function DeliverVegetablesQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_deliver_vegetables then
			self.sv.saved.completedStages[Stages.read_log] = true
		end
	end

	if data.event == QuestEvent.Vegetables then
		self.sv.saved.completedStages[Stages.suck_crates] = true
	end

	-- Detect player at the wreck for the first time
	if not self.sv.saved.completedStages[Stages.reach_station] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_deliver_vegetables" ) then
			self.sv.saved.completedStages[Stages.reach_station] = true
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.reach_station] then
		self.sv.saved.stage = Stages.reach_station
	elseif not self.sv.saved.completedStages[Stages.suck_crates] then
		self.sv.saved.stage = Stages.suck_crates
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.suck_crates] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_deliver_vegetables" )
		QuestManager.Sv_TryActivateQuest( "quest_woc_temple" )
	end

	self:sv_saveAndSync()
end


function DeliverVegetablesQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
end

function DeliverVegetablesQuest.client_onRefresh( self )
end

function DeliverVegetablesQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_marker.bertha", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.suck_crates then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_marker.bertha", true )
	end

	self:cl_updateProgress( data.stage )
end

function DeliverVegetablesQuest.cl_updateProgress( self, stage )
	if stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Vegetables_Logbook")
	elseif stage == Stages.reach_station then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Vegetables_ReachStation")
	elseif stage == Stages.suck_crates then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Vegetables_SuckCrates")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
