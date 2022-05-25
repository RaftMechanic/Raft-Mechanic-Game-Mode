dofile("$MOD_DATA/Scripts/game/raft_items.lua")

---@type ShapeClass
Torch = class(nil)
Torch.connectionInput = 1
Torch.connectionOutput = 1
Torch.maxParentCount = 1
Torch.maxChildCount = 1

function Torch:server_onCreate()
    self.sv = self.storage:load() or { active = false }
    self.network:setClientData(self.sv)
end

function Torch:client_onCreate()
    self.effect = sm.effect.createEffect("Fire - small01", self.interactable)
    self.effect:setOffsetPosition(sm.vec3.new(0, 0.35, 0))
    if self.shape.uuid == obj_torch_lit then
        self.effect:start()
    end
end

function Torch.client_canInteract( self, character, state )
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    if self.interactable:getSingleParent() then
        sm.gui.setInteractionText("", o1.."#c60000"..language_tag("Sail_Controlled")..o2 )
        return false
    end

    return true
end

function Torch:client_onInteract(_, state)
    if not state then return end
    self.network:sendToServer("sv_changeState")
end

function Torch:sv_changeState()
    if not self.interactable:getSingleParent() then
        self.sv.active = not self.sv.active
    end

    self.shape:replaceShape(self.shape.uuid ~= obj_torch_lit and obj_torch_lit or obj_torch_burnt)
    self.network:setClientData(self.sv)
    self.storage:save(self.sv)
end

function Torch:client_onClientDataUpdate( data, channel )
    if data.active then
        self.effect:start()
    else
        self.effect:stop()
    end
end

function Torch:server_onFixedUpdate()
    local prevActive = self.sv.active
    local parent = self.interactable:getSingleParent()
    if parent then
        self.sv.active = parent:isActive()
    end

    if prevActive ~= self.sv.active then
        self:sv_changeState()
    end
end
