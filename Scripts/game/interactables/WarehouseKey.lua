WarehouseKey = class()

--RAFT START
dofile("$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua")
dofile("$CONTENT_DATA/Scripts/game/managers/QuestManager.lua")

function WarehouseKey.server_canErase( self )
	return QuestManager.Sv_GotQuestLog( "quest_scrap_city" )
end

function WarehouseKey.client_canInteract(self)
	if not (QuestManager.Cl_IsQuestActive("quest_scrap_city") and QuestManager.cl_getQuestProgressString(g_questManager, "quest_scrap_city") ~= language_tag("Quest_FindTrader_TalkTrader")) then
		sm.gui.setInteractionText("", "", language_tag("QuestItemTooEarly"))
		return false
	end
	return true
end
