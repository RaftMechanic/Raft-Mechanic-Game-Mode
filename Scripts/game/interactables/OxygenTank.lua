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

        if seatedChar then
            local seatedPlayer = seatedChar:getPlayer()
            if seatedPlayer ~= nil and self.sv.player == nil then
                self.sv.player = seatedPlayer
                sm.event.sendToPlayer(self.sv.player, "sv_e_OxygenTank", 1)
            end

        elseif self.sv.player then
            sm.event.sendToPlayer(self.sv.player, "sv_e_OxygenTank", -1)
            self.sv.player = nil
        end
    end
end