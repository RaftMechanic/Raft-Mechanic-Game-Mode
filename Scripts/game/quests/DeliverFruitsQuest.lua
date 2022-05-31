dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

DeliverFruitsQuest = class()
DeliverFruitsQuest.isSaveObject = true

local Stages = {
	talk_trader = 1,
	read_log = 2,
	reach_station = 3,
	suck_crates = 4
}

function DeliverFruitsQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.talk_trader
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.TraderTalk, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.ReadLog, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.AreaTriggerEnter, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.Fruits, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function DeliverFruitsQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
	self.scriptableObject:setPublicData(self.sv.saved)
end

function DeliverFruitsQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_deliver_fruits then
			self.sv.saved.completedStages[Stages.read_log] = true
		end
	end

	if data.event == QuestEvent.Fruits then
		self.sv.saved.completedStages[Stages.suck_crates] = true
	end

	if data.event == QuestEvent.TraderTalk then
		self.sv.saved.completedStages[Stages.talk_trader] = true
		self.sv.saved.log = true
	end

	-- Detect player at the wreck for the first time
	if not self.sv.saved.completedStages[Stages.reach_station] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_deliver_fruits" ) then
			self.sv.saved.completedStages[Stages.reach_station] = true
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.talk_trader] then
		self.sv.saved.stage = Stages.talk_trader
	elseif not self.sv.saved.completedStages[Stages.read_log] then
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
		QuestManager.Sv_CompleteQuest( "quest_deliver_fruits" )
		QuestManager.Sv_TryActivateQuest( "quest_scrap_city" )
	end

	self:sv_saveAndSync()
end


function DeliverFruitsQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
end

function DeliverFruitsQuest.client_onRefresh( self )
end

function DeliverFruitsQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_marker.bertha", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.talk_trader then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", true )
	elseif data.stage == Stages.suck_crates then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_marker.bertha", true )
	end

	self:cl_updateProgress( data.stage )
end

function DeliverFruitsQuest.cl_updateProgress( self, stage )
	if stage == Stages.talk_trader then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_FindTrader_TalkTrader")
	elseif stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Fruits_Logbook")
	elseif stage == Stages.reach_station then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Vegetables_ReachStation")
	elseif stage == Stages.suck_crates then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Vegetables_SuckCrates")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
