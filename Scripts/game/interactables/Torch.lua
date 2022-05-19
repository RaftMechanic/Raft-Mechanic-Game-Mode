dofile("$MOD_DATA/Scripts/game/raft_items.lua")

---@type ShapeClass
Torch = class(nil)
Torch.connectionInput = 1
Torch.connectionOutput = 1
Torch.maxParentCount = 1
Torch.maxChildCount = 1
function Torch:server_onCreate()
    self.network:sendToClients("cl_createEffect")
end

function Torch:client_onCreate()
    self:cl_createEffect()
end

function Torch:cl_createEffect()
    self.effect = sm.effect.createEffect("Fire - small01", self.interactable)
    self.effect:setOffsetPosition(sm.vec3.new(0, 0.35, 0))
    if self.shape.uuid == obj_torch_lit then
        self.effect:start()
    end
end

function Torch:client_onInteract(_, state)
    if not state then return end
    local parent = self.interactable:getSingleParent()
    if parent then return end
    self.network:sendToServer("sv_changeState")
end

function Torch:sv_changeState()
    self.shape:replaceShape(self.shape.uuid ~= obj_torch_lit and obj_torch_lit or obj_torch_burnt)
    self.network:sendToClients("cl_changeState")
end

function Torch:cl_changeState()
    local parent = self.interactable:getSingleParent()
    local notBurning = self.shape.uuid ~= obj_torch_lit
    if parent then
        notBurning = not notBurning
    end
    if notBurning then
        self.effect:start()
    else
        self.effect:stopImmediate()
    end
end

function Torch:server_onFixedUpdate()
    if not self.effect then
        return
    end
    local parent = self.interactable:getSingleParent()
    local isBurining = self.shape.uuid ~= sm.uuid.new("93e8a46a-5c24-42d2-8261-67be84e05ccf")
    self.interactable:setActive(not isBurining)
    if not parent then return end
    if parent:isActive() == isBurining then
        self:sv_changeState()
    end
end
