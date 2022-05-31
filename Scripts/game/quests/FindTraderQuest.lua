dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

FindTraderQuest = class()
FindTraderQuest.isSaveObject = true

local Stages = {
	read_log = 1,
	reach_trader = 2,
	talk_trader = 3
}

function FindTraderQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.read_log
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.ReadLog, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.AreaTriggerEnter, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.TraderTalk, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function FindTraderQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
end

function FindTraderQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_find_trader then
			self.sv.saved.completedStages[Stages.read_log] = true
		end

	elseif data.event ==QuestEvent.TraderTalk then
		self.sv.saved.completedStages[Stages.talk_trader] = true
	end

	-- Detect player at the wreck for the first time
	if not self.sv.saved.completedStages[Stages.reach_trader] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_find_trader" ) then
			self.sv.saved.completedStages[Stages.reach_trader] = true
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.reach_trader] then
		self.sv.saved.stage = Stages.reach_trader
	elseif not self.sv.saved.completedStages[Stages.talk_trader] then
		self.sv.saved.stage = Stages.talk_trader
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.talk_trader] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_TryActivateQuest( "quest_deliver_vegetables" )
	end

	self:sv_saveAndSync()
end


function FindTraderQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
	self.scriptableObject.clientPublicData.title = language_tag("Quest_FindTrader")
	self.scriptableObject.clientPublicData.isMainQuest = true
end

function FindTraderQuest.client_onRefresh( self )
end

function FindTraderQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.talk_trader then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", true )
	end

	self:cl_updateProgress( data.stage )
end

function FindTraderQuest.cl_updateProgress( self, stage )
	if stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_FindTrader_Logbook")
	elseif stage == Stages.reach_trader then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_FindTrader_ReachTrader")
	elseif stage == Stages.talk_trader then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_FindTrader_TalkTrader")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
