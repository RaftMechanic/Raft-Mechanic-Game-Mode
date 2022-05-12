OxygenTank = class()
OxygenTank.maxChildCount = 0
OxygenTank.maxParentCount = 1
OxygenTank.connectionInput = sm.interactable.connectionType.power + sm.interactable.connectionType.seated
OxygenTank.connectionOutput = sm.interactable.connectionType.none
OxygenTank.colorNormal = sm.color.new("#ff3200")
OxygenTank.colorHighlight = sm.color.new("#ff1100")

function OxygenTank:server_onCreate()
    self.sv = {}
end

function OxygenTank:server_onFixedUpdate( dt )
    local parent = self.interactable:getSingleParent()
    if parent then
        local seatedChar = parent:getSeatCharacter()
        if not seatedChar and self.sv.player then
            sm.event.sendToPlayer(self.sv.player, "sv_setBlockBreatheDeplete", false)
            self.sv.player = nil
        else
            local seatedPlayer = seatedChar:getPlayer()
            if seatedPlayer ~= nil and self.sv.player == nil then
                self.sv.player = seatedPlayer
                sm.event.sendToPlayer(self.sv.player, "sv_setBlockBreatheDeplete", true)
            end
        end
    end
end