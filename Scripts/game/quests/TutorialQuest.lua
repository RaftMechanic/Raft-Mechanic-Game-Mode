dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/quest_util.lua" )

TutorialQuest = class()
TutorialQuest.isSaveObject = true

local Stages = {
	sleep_hammock = 1,
	open_workbench = 2,
	craft_hammer = 3
}

function TutorialQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.sleep_hammock
		self.sv.saved.stageData = {}
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.Sleep, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.Workbench, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.InventoryChanges, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function TutorialQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage, stageData = self.sv.saved.stageData } )
end

function TutorialQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.Sleep then
		--sleep in hammock, duh. like why do we leave these obvious comments everywhre? I really don't wanna do this quest stuff.... pls help me...
		self.sv.saved.completedStages[Stages.sleep_hammock] = true
	elseif data.event == QuestEvent.Workbench then
		self.sv.saved.completedStages[Stages.open_workbench] = true
	elseif data.event == QuestEvent.InventoryChanges then
		-- Find hammer
		if FindInventoryChange( data.params.changes, tool_wood_hammer ) > 0 then
			self.sv.saved.completedStages[Stages.craft_hammer] = true
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.sleep_hammock] then
		self.sv.saved.stage = Stages.sleep_hammock
	elseif not self.sv.saved.completedStages[Stages.open_workbench] then
		self.sv.saved.stage = Stages.open_workbench
	elseif not self.sv.saved.completedStages[Stages.craft_hammer] then
		self.sv.saved.stage = Stages.craft_hammer
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.craft_hammer] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_raft_tutorial" )
		QuestManager.Sv_TryActivateQuest( "quest_rangerstation" )
	end

	self:sv_saveAndSync()
end


function TutorialQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
	self.scriptableObject.clientPublicData.title = language_tag("Quest_Tutorial")
	self.scriptableObject.clientPublicData.isMainQuest = true
end

function TutorialQuest.client_onRefresh( self )
end

function TutorialQuest.client_onClientDataUpdate( self, data )
	self:cl_updateProgress( data.stage, data.stageData )
end

function TutorialQuest.cl_updateProgress( self, stage, stageData )
	if stage == Stages.sleep_hammock then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Tutorial_Sleep")
	elseif stage == Stages.open_workbench then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Tutorial_Workbench")
	elseif stage == Stages.craft_hammer then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_Tutorial_Hammer")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
