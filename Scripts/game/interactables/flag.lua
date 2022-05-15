dofile( "$CONTENT_DATA/Scripts/game/survival_quests.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua" )

Flag = class()

function Flag.client_onCreate(self)
    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.effect:setOffsetPosition(sm.vec3.new(0, -0.28, 0))
    self.effect:setParameter("uuid", sm.uuid.new("4a971f7d-14e6-454d-bce8-0879243c4859"))
	self.effect:setParameter("color", sm.color.new(1,0,0))
	self.effect:setScale(sm.vec3.new(0.15, 0.15, 0.4))
    self.effect:start()
end

function Flag.client_onUpdate( self, dt )
    if not self.effect:isPlaying() then self.effect:start() end

    local point = sm.vec3.new(0, 0, 0)

    --Quest helper
    if not g_questManager.Cl_IsQuestComplete(quest_radio_location) then
        point = sm.vec3.new(-1820.5, 167.5, -7)
    elseif not g_questManager.Cl_IsQuestComplete(quest_find_trader) then
        point = sm.vec3.new(1536, 2048, 20)
    end

    local direction = self.shape:transformPoint(point)
    direction.y = 0
    self.effect:setOffsetRotation(sm.vec3.getRotation(sm.vec3.new(0, 0, 1), -direction))
end