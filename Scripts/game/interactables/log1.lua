dofile("$SURVIVAL_DATA/Scripts/game/survival_quests.lua")

Log = class()
Log.maxParentCount = 0
Log.maxChildCount = 0
Log.connectionInput = sm.interactable.connectionType.none
Log.connectionOutput = sm.interactable.connectionType.none

function Log.server_addLog( self, character, state )
	g_questManager:sv_completeQuest(quest_radio_interactive)
    	self.network:sendToClients("cl_playEffect")
	sm.shape.destroyPart( self.shape )
end

function Log.client_onInteract( self, character, state )
	if state == true then
       		 self.network:sendToServer("server_addLog")
	end
end

function Log.client_canInteract(self)
sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Use" ), "#{RAFT_ADD_TO_LOGBOOK} " )
    return not g_questManager:cl_isQuestComplete(quest_radio_interactive)
end

function Log.cl_playEffect(self)
    self.effect:start()
end
