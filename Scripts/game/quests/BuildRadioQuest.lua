dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$SURVIVAL_DATA/scripts/game/quest_util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/raft_logs.lua")
dofile( "$SURVIVAL_DATA/scripts/game/survival_items.lua" )
dofile( "$CONTENT_DATA/scripts/game/raft_items.lua" )

BuildRadioQuest = class()
BuildRadioQuest.isSaveObject = true

local Stages = {
	read_log = 1,
	get_craftbot = 2,
	get_wood = 3,
	get_metal = 4,
	get_component = 5,
	craft_antenna = 6,
	use_antenna = 7
}

function BuildRadioQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.read_log
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.ReadLog, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.Craftbot, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.InventoryChanges, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.Antenna, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function BuildRadioQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
end

function BuildRadioQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.ReadLog then
		if data.params.uuid == log_radio then
			self.sv.saved.completedStages[Stages.read_log] = true
		end

	elseif data.event == QuestEvent.Craftbot then
		self.sv.saved.completedStages[Stages.get_craftbot] = true

	elseif data.event == QuestEvent.InventoryChanges then
		-- check wood
		if data.params.container:canSpend(blk_wood1, 20) then
			self.sv.saved.completedStages[Stages.get_wood] = true
		end
		-- check metal
		if data.params.container:canSpend(blk_metal1, 15) then
			self.sv.saved.completedStages[Stages.get_metal] = true
		end
		-- check componets
		if data.params.container:canSpend(obj_consumable_component, 2) then
			self.sv.saved.completedStages[Stages.get_component] = true
		end

		if FindInventoryChange( data.params.changes, obj_radio_antenna ) > 0 then
			self.sv.saved.completedStages[Stages.craft_antenna] = true
		end
	elseif data.event == QuestEvent.Antenna then
		self.sv.saved.completedStages[Stages.use_antenna] = true

	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.read_log] then
		self.sv.saved.stage = Stages.read_log
	elseif not self.sv.saved.completedStages[Stages.get_craftbot] then
		self.sv.saved.stage = Stages.get_craftbot
	elseif not self.sv.saved.completedStages[Stages.get_wood] then
		self.sv.saved.stage = Stages.get_wood
	elseif not self.sv.saved.completedStages[Stages.get_metal] then
		self.sv.saved.stage = Stages.get_metal
	elseif not self.sv.saved.completedStages[Stages.get_component] then
		self.sv.saved.stage = Stages.get_component
	elseif not self.sv.saved.completedStages[Stages.craft_antenna] then
		self.sv.saved.stage = Stages.craft_antenna
	elseif not self.sv.saved.completedStages[Stages.use_antenna] then
		self.sv.saved.stage = Stages.use_antenna
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.use_antenna] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_radio_interactive" )
		QuestManager.Sv_TryActivateQuest( "quest_radio_location" )
	end

	self:sv_saveAndSync()
end


function BuildRadioQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
end

function BuildRadioQuest.client_onRefresh( self )
end

function BuildRadioQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_radio_interactive.marker_crafter", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.get_craftbot then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_radio_interactive.marker_crafter", true )
	end

	self:cl_updateProgress( data.stage )
end

function BuildRadioQuest.cl_updateProgress( self, stage )
	if stage == Stages.read_log then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_BuildRadio_Logbook")
	elseif stage == Stages.get_craftbot then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_BuildRadio_Craftbot")
	elseif stage == Stages.get_wood then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_BuildRadio_Wood")
	elseif stage == Stages.get_metal then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_BuildRadio_Metal")
	elseif stage == Stages.get_component then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_BuildRadio_Components")
	elseif stage == Stages.craft_antenna then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_BuildRadio_Craft_Antenna")
	elseif stage == Stages.use_antenna then
		self.scriptableObject.clientPublicData.progressString = language_tag("Quest_BuildRadio_Use_Antenna")
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
