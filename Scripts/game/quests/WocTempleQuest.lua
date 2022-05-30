dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

WocTempleQuest = class()
WocTempleQuest.isSaveObject = true

local Stages = {
	talk_trader = 1,
	read_log = 2,
	reach_temple = 3,
	find_temple = 4,
	get_recipe = 5
}

function WocTempleQuest.server_onCreate( self )
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
	QuestManager.Sv_SubscribeEvent( QuestEvent.SunshakeRecipe, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function WocTempleQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
end

function WocTempleQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_woc_temple then
			self.sv.saved.completedStages[Stages.read_log] = true
		end
	end

	if data.event == QuestEvent.TraderTalk then
		self.sv.saved.completedStages[Stages.talk_trader] = true
	end

	-- Detect player at the wreck for the first time
	if not self.sv.saved.completedStages[Stages.reach_temple] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_woc_temple" ) then
			self.sv.saved.completedStages[Stages.reach_temple] = true
		end
	elseif not self.sv.saved.completedStages[Stages.find_temple] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_woc_temple.temple" ) then
			self.sv.saved.completedStages[Stages.find_temple] = true
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.talk_trader] then
		self.sv.saved.stage = Stages.talk_trader
	elseif not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.reach_temple] then
		self.sv.saved.stage = Stages.reach_temple
	elseif not self.sv.saved.completedStages[Stages.find_temple] then
		self.sv.saved.stage = Stages.find_temple
	elseif not self.sv.saved.completedStages[Stages.get_recipe] then
		self.sv.saved.stage = Stages.get_recipe
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.get_recipe] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_woc_temple" )
		QuestManager.Sv_TryActivateQuest( "quest_deliver_fruits" )
	end

	self:sv_saveAndSync()
end


function WocTempleQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
end

function WocTempleQuest.client_onRefresh( self )
end

function WocTempleQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.talk_trader then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest.marker_trader", true )
	end

	self:cl_updateProgress( data.stage )
end

function WocTempleQuest.cl_updateProgress( self, stage )
	if stage == Stages.talk_trader then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_FindTrader_TalkTrader")
	elseif stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_WocTemple_Logbook")
	elseif stage == Stages.reach_temple then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_WocTemple_ReachTemple")
	elseif stage == Stages.find_temple then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_WocTemple_FindTemple")
	elseif stage == Stages.get_recipe then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_WocTemple_GetRecipe")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
