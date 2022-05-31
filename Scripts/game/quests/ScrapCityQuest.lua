dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

ScrapCityQuest = class()
ScrapCityQuest.isSaveObject = true

local Stages = {
	talk_trader = 1,
	read_log = 2,
	reach_city = 3,
	find_ruin = 4,
	get_key = 5
}

function ScrapCityQuest.server_onCreate( self )
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
	QuestManager.Sv_SubscribeEvent( QuestEvent.InventoryChanges, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function ScrapCityQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
	self.scriptableObject:setPublicData(self.sv.saved)
end

function ScrapCityQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.TraderTalk then
		self.sv.saved.completedStages[Stages.talk_trader] = true
		self.sv.saved.log = true
	end

	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_scrap_city then
			self.sv.saved.completedStages[Stages.read_log] = true
		end
	end

	-- Detect player at the wreck for the first time
	if not self.sv.saved.completedStages[Stages.reach_city] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_scrap_city" ) then
			self.sv.saved.completedStages[Stages.reach_city] = true
		end

	elseif not self.sv.saved.completedStages[Stages.find_ruin] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_scrap_city.ruin" ) then
			self.sv.saved.completedStages[Stages.find_ruin] = true
		end
	end

	if data.event == QuestEvent.InventoryChanges then
		if FindInventoryChange( data.params.changes, obj_survivalobject_keycard) > 0 then
			self.sv.saved.completedStages[Stages.get_key] = true
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.talk_trader] then
		self.sv.saved.stage = Stages.talk_trader
	elseif not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.reach_city] then
		self.sv.saved.stage = Stages.reach_city
	elseif not self.sv.saved.completedStages[Stages.find_ruin] then
		self.sv.saved.stage = Stages.find_ruin
	elseif not self.sv.saved.completedStages[Stages.get_key] then
		self.sv.saved.stage = Stages.get_key
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.get_key] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_scrap_city" )
		QuestManager.Sv_TryActivateQuest( "quest_warehouse" )
	end

	self:sv_saveAndSync()
end


function ScrapCityQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
end

function ScrapCityQuest.client_onRefresh( self )
end

function ScrapCityQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.talk_trader then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", true )
	end

	self:cl_updateProgress( data.stage )
end

function ScrapCityQuest.cl_updateProgress( self, stage )
	if stage == Stages.talk_trader then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_FindTrader_TalkTrader")
	elseif stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_ScrapCity_Logbook")
	elseif stage == Stages.reach_city then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_ScrapCity_ReachCity")
	elseif stage == Stages.find_ruin then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_ScrapCity_FindRuin")
	elseif stage == Stages.get_key then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_ScrapCity_GetKey")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
