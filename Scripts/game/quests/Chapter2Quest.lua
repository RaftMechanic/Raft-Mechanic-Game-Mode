dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

Chapter2Quest = class()
Chapter2Quest.isSaveObject = true

local Stages = {
	talk_trader = 1,
	read_log = 2,
	does_not_exist = 3
}

function Chapter2Quest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.talk_trader
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.TraderTalk, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.ReadLog, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function Chapter2Quest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
	self.scriptableObject:setPublicData(self.sv.saved)
end

function Chapter2Quest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.TraderTalk then
		self.sv.saved.completedStages[Stages.talk_trader] = true
		self.sv.saved.log = true
	end

	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_chapter2 then
			self.sv.saved.completedStages[Stages.read_log] = true
		end
	end


	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.talk_trader] then
		self.sv.saved.stage = Stages.talk_trader
	elseif not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.does_not_exist] then
		self.sv.saved.stage = Stages.does_not_exist
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.does_not_exist] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_chapter2" )
		--QuestManager.Sv_TryActivateQuest( "quest_chapter2" )
	end

	self:sv_saveAndSync()
end


function Chapter2Quest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
	self.scriptableObject.clientPublicData.title = language_tag("Quest_Chapter2")
	self.scriptableObject.clientPublicData.isMainQuest = true
end

function Chapter2Quest.client_onRefresh( self )
end

function Chapter2Quest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.talk_trader then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", true )
	end

	self:cl_updateProgress( data.stage )
end

function Chapter2Quest.cl_updateProgress( self, stage )
	if stage == Stages.talk_trader then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_FindTrader_TalkTrader")
	elseif stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Chapter2_Logbook")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
