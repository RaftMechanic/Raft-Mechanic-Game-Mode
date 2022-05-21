local CONTENT_DATA = "$CONTENT_667b4c22-cc1a-4a2b-bee8-66a6c748d40e"
---@type ToolClass
TorchTool = class()


local renderables = { "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer.rend" }
local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend" }

local currentRenderablesTp = {}
local currentRenderablesFp = {}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

function TorchTool:client_onEquip()
    self.equipped = true
    if not self.effect then
        self.network:sendToServer("sv_createEffect")
    end
end

function TorchTool:client_onUnequip()
    self.equipped = false
    self.network:sendToServer("sv_stopEffect")
end

---@param player Player
function TorchTool:sv_createEffect(_, player)
    self.network:sendToClients("cl_effect", player)
end

---@param player Player
function TorchTool:cl_effect(player)
    self.effect = sm.effect.createEffect("Fire - small01", player:getCharacter())
    self.effect:setOffsetPosition(sm.vec3.new(-1, 1, 0))
end

function TorchTool:sv_startEffect()
    self.network:sendToClients("cl_startEffect")
end

function TorchTool:cl_startEffect()
    if self.effect:isPlaying() then return end
    self.effect:start()
end

function TorchTool:sv_stopEffect()
    self.network:sendToClients("cl_stopEffect")
end

function TorchTool:cl_stopEffect()
    self.effect:stopImmediate()
end

function TorchTool:client_onFixedUpdate()
    if not self.equipped then return end
    ---@diagnostic disable-next-line: missing-parameter
    if sm.localPlayer.getPlayer():getCharacter():isSwimming() then
        self.network:sendToServer("sv_stopEffect")
    else
        self.network:sendToServer("sv_startEffect")
    end
end
