dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

RadioLocationQuest = class()
RadioLocationQuest.isSaveObject = true

local Stages = {
	read_log = 1,
	get_cotton = 2,
	craft_windsock = 3,
	craft_sail = 4,
	find_wreck = 5,
	explore_wreck = 6
}

function RadioLocationQuest.server_onCreate( self )
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
	QuestManager.Sv_SubscribeEvent( QuestEvent.TraderNotes, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function RadioLocationQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
end

function RadioLocationQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_radio_signal then
			self.sv.saved.completedStages[Stages.read_log] = true
		end

	elseif data.event == QuestEvent.InventoryChanges then
		if FindInventoryChange( data.params.changes, obj_resource_cotton ) > 0 or data.params.container:canSpend(obj_resource_cotton, 1) then
			self.sv.saved.completedStages[Stages.get_cotton] = true
		end
		if FindInventoryChange( data.params.changes, obj_windsock ) > 0 then
			self.sv.saved.completedStages[Stages.craft_windsock] = true
		end
		if FindInventoryChange( data.params.changes, obj_sail ) > 0 then
			self.sv.saved.completedStages[Stages.craft_sail] = true
		end

	elseif data.event ==QuestEvent.TraderNotes then
		self.sv.saved.completedStages[Stages.explore_wreck] = true
	end

	-- Detect player at the wreck for the first time
	if not self.sv.saved.completedStages[Stages.find_wreck] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_radio_location" ) then
			self.sv.saved.completedStages[Stages.find_wreck] = true
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.get_cotton] then
		self.sv.saved.stage = Stages.get_cotton
	elseif not self.sv.saved.completedStages[Stages.craft_windsock] then
		self.sv.saved.stage = Stages.craft_windsock
	elseif not self.sv.saved.completedStages[Stages.craft_sail] then
		self.sv.saved.stage = Stages.craft_sail
	elseif not self.sv.saved.completedStages[Stages.find_wreck] then
		self.sv.saved.stage = Stages.find_wreck
	elseif not self.sv.saved.completedStages[Stages.explore_wreck] then
		self.sv.saved.stage = Stages.explore_wreck
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.explore_wreck] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_radio_location" )
		QuestManager.Sv_TryActivateQuest( "quest_find_trader" )
	end

	self:sv_saveAndSync()
end


function RadioLocationQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
end

function RadioLocationQuest.client_onRefresh( self )
end

function RadioLocationQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_radio_interactive.marker_crafter", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.get_craftbot then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_radio_interactive.marker_crafter", true )
	end

	self:cl_updateProgress( data.stage )
end

function RadioLocationQuest.cl_updateProgress( self, stage )
	if stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RadioSignal_Logbook")
	elseif stage == Stages.get_cotton then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RadioSignal_Cotton")
	elseif stage == Stages.craft_windsock then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RadioSignal_Windsock")
	elseif stage == Stages.craft_sail then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RadioSignal_Sail")
	elseif stage == Stages.find_wreck then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RadioSignal_FindWreck")
	elseif stage == Stages.explore_wreck then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_RadioSignal_ExploreWreck")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
