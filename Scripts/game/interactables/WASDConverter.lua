Converter = class()
Converter.maxChildCount = -1
Converter.maxParentCount = 1
Converter.connectionInput = sm.interactable.connectionType.power
Converter.connectionOutput = sm.interactable.connectionType.logic
Converter.colorNormal = sm.color.new("#ff3200")
Converter.colorHighlight = sm.color.new("#ff1100")

local modes = {
    "w",
    "a",
    "s",
    "d"
}

local inputs = {
    forward = {
        [1] = "w",
        [-1] = "s"
    },
    steer = {
        [1] = "d",
        [-1] = "a"
    }
}

local uv = {
    w = {
        [0] = 0,
        [1] = 6,
    },
    a = {
        [0] = 1,
        [1] = 7,
    },
    s = {
        [0] = 2,
        [1] = 8,
    },
    d = {
        [0] = 3,
        [1] = 9,
    }
}

function Converter:server_onCreate()
    self.sv = {}
    self.sv.data = self.storage:load()

    if self.sv.data == nil then
        self.sv.data = {
            count = 1
        }
    end

    self.network:sendToClients("cl_updateData", self.sv.data)
    self:sv_updateUV( 0 )
end

function Converter:client_onCreate()
    self.cl = {
        data = {}
    }
end

function Converter:server_onFixedUpdate( dt )
    if not self.sv or not self.sv.data then return end

    local parent = self.interactable:getSingleParent()
    if not parent then return end

    local selectedInput = modes[self.sv.data.count]
    local forward = parent:getSteeringPower()
    local steer = parent:getSteeringAngle()

    if forward ~= 0 and inputs.forward[forward] == selectedInput and not self.interactable:isActive() then
        self:sv_updateState( { active = true, power = forward } )
    elseif forward == 0 and isAnyOf(selectedInput, inputs.forward) and self.interactable:isActive() then
        self:sv_updateState( { active = false, power = 0 } )
    end

    if steer ~= 0 and inputs.steer[steer] == selectedInput and not self.interactable:isActive() then
        self:sv_updateState( { active = true, power = steer } )
    elseif steer == 0 and isAnyOf(selectedInput, inputs.steer) and self.interactable:isActive() then
        self:sv_updateState( { active = false, power = 0 } )
    end
end

function Converter:cl_updateData( data )
    self.cl.data = data
end

function Converter:sv_updateState( args )
    self.interactable:setActive( args.active )
    self.interactable:setPower( math.abs(args.power) ) --thank you thrusters

    self:sv_updateUV( args.power )
end

function Converter:sv_updateUV( power )
    local index = uv[modes[self.sv.data.count]][math.abs(power)]
    self.network:sendToClients("cl_uvUpdate", index)
end

function Converter:sv_save()
    self.storage:save( self.sv.data )
    self.network:sendToClients("cl_updateData", self.sv.data)
    self:sv_updateUV(0)
end

function Converter:cl_uvUpdate( index )
    self.interactable:setUvFrameIndex( index )
end

function Converter:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
	sm.gui.setInteractionText( "", o1..language_tag("CreationRotator_CurrentMode")..modes[self.cl.data.count]:upper()..o2 )
    sm.gui.setInteractionText(
        "",
        sm.gui.getKeyBinding( "Use", true ).. "/"..sm.gui.getKeyBinding( "Tinker", true ),
        language_tag("Switch_mode"))

    return true
end

function Converter:client_onInteract( char, lookAt )
    if lookAt then
        self.network:sendToServer("sv_changeCount", "add")
        sm.audio.play("PaintTool - ColorPick")
    end
end

function Converter:client_onTinker( char, lookAt )
    if lookAt then
        self.network:sendToServer("sv_changeCount", "subtract")
        sm.audio.play("PaintTool - ColorPick")
    end
end

function Converter:sv_changeCount( type )
    if type == "add" then
        self.sv.data.count = self.sv.data.count < #modes and self.sv.data.count + 1 or 1
    else
        self.sv.data.count = self.sv.data.count > 1 and self.sv.data.count - 1 or #modes
    end

    self:sv_save()
end