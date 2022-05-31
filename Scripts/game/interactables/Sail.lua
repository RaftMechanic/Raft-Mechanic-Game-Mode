dofile( "$CONTENT_DATA/Scripts/game/raft_quests.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/WindManager.lua" )

---@type Interactable
Sail = class()
Sail.maxParentCount = 1
Sail.maxChildCount = 0
Sail.connectionInput = sm.interactable.connectionType.logic
Sail.connectionOutput = sm.interactable.connectionType.none
Sail.colorNormal = sm.color.new( 0xff8000ff )
Sail.colorHighlight = sm.color.new( 0xff9f3aff )

local POWER = 6250
local MAX_SPEED = 10


function Sail.server_onCreate(self)
    self.sv = {}
    self.sv.active = false
    self.network:setClientData( self.sv.active )
end

function Sail.sv_changeState(self)
    self.sv.active = not self.sv.active
    self.network:setClientData( self.sv.active )
end

function Sail.server_onFixedUpdate(self, dt)
    local parent = self.interactable:getSingleParent()
	if parent then
        if parent.active ~= self.sv.active then
            self:sv_changeState()
        end
    end

    if self.sv.active and self.shape:getVelocity():length() < MAX_SPEED and self.shape:getWorldPosition().z > -1.9 then
        local windDirection = getWindDir(self.shape:getWorldPosition())

        local sailDirection = -self.shape:getUp()
        sailDirection.z = 0
        sailDirection = sailDirection:normalize()

        local cosine = windDirection:dot(sailDirection)/(windDirection:length() + sailDirection:length()) * -2
        --sm.gui.chatMessage(tostring(cosine))

        local speedFraction = 1 - (self.shape:getVelocity():length() / MAX_SPEED)
        local force = sailDirection * (POWER * speedFraction * dt * cosine)
        force.z = 0
        sm.physics.applyImpulse(self.shape, force, true)
        --print(self.shape:getVelocity():length())
    end
end



function Sail.client_onCreate(self)
    self.cl = {}
    self.cl.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.cl.effect:setOffsetPosition(sm.vec3.new(0, 1, 0))
    self.cl.effect:setScale(sm.vec3.new(0.118, 0.135, 0.1))
    self.cl.effect:setParameter("uuid", sm.uuid.new("4a971f7d-14e6-454d-bce8-0879243c4934"))
    self.cl.active = false
end

function Sail.client_onClientDataUpdate( self, state )
	self.cl.active = state
end

function Sail:client_onUpdate( dt )
    if self.cl.active and not self.cl.effect:isPlaying() then
        self.cl.effect:start()
    elseif not self.cl.active and self.cl.effect:isPlaying() then
        self.cl.effect:stop()
    end
end

function Sail.client_canInteract( self, character, state )
    local parent = self.interactable:getSingleParent()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    if parent then
        sm.gui.setInteractionText("", o1.."#c60000"..language_tag("Sail_Controlled")..o2 )
        return false
    end

    local keyBindingText = sm.gui.getKeyBinding( "Use", true )
    if self.cl.active then
        sm.gui.setInteractionText("", keyBindingText, language_tag("Sail_Tie"))
    else
        sm.gui.setInteractionText("", keyBindingText, language_tag("Sail_Lower"))
    end
    return true
end

function Sail.client_onInteract( self, character, state )
	if state then
        self.network:sendToServer("sv_changeState")
    end
end