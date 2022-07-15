Steer = class()
Steer.maxChildCount = -1
Steer.maxParentCount = -1
Steer.connectionInput = sm.interactable.connectionType.power + sm.interactable.connectionType.logic
Steer.connectionOutput = sm.interactable.connectionType.logic
Steer.colorNormal = sm.color.new("#00ff33")
Steer.colorHighlight = sm.color.new("#00ff00")

local modes = {
    language_tag("CreationRotator_Ver_Hor"),
    language_tag("CreationRotator_Ver"),
    language_tag("CreationRotator_Hor"),
    language_tag("CreationRotator_Roll")
}

local controlModes = {
    language_tag("CreationRotator_Input_mouse"),
    language_tag("CreationRotator_Input_wasd")
}

local maxForceMult = 25
local massDivider = 100
local l_inputColours = {
    sm.color.new("f5f071ff"),
    sm.color.new("e2db13ff"),
    sm.color.new("7f7f7fff"),
    sm.color.new("a0ea00ff")
}

function Steer:server_onCreate()
    self.sv = {}
    self.sv.data = self.storage:load()

    if self.sv.data == nil then
        self.sv.data = {
            count = 1,
            controlMethodCount = 1,
            slider = 1
        }
    end

    if self.sv.data.controlMethodCount == nil then self.sv.data.controlMethodCount = 1 end

    self.network:sendToClients("cl_updateData", self.sv.data)
    self:sv_updateState( { active = false, power = 0, index = 1  } )
end

function Steer:sv_onSliderChange( sliderPos )
    self.sv.data.slider = sliderPos
    self:sv_save()
end

function Steer:server_onFixedUpdate( dt )
    if not self.sv or not self.sv.data then return end

    local l_active, l_left, l_right, l_up, l_down = self:sv_getLogicInputs()
    local seatParent = self.interactable:getParents( sm.interactable.connectionType.power )[1]
    if not seatParent or l_active and not l_active.active then
        if self.interactable.active then
            self:sv_updateState( { active = false, power = 0, index = 1  } )
        end

        return
    end

    local seatedChar = seatParent:getSeatCharacter()
    if not seatedChar and not l_left and not l_right and not l_up and not l_down then
        if self.interactable.active then
            self:sv_updateState( { active = false, power = 0, index = 1  } )
        end

        return
    end

    local forceDir = sm.vec3.zero()
    local parentShape = seatParent:getShape()
    local parentRight = parentShape:getRight()
    local parentAt = parentShape:getAt()
    local parentDir = parentRight:cross(parentAt) --a seat's getAt is upwards, I want a forward direction
    if seatedChar then
        if controlModes[self.sv.data.controlMethodCount] == controlModes[1] then
            local charDir = seatedChar:getDirection()
            forceDir = parentDir:cross(charDir)
        else
            local forward = seatParent:getSteeringPower()
            local steer = seatParent:getSteeringAngle()
            forceDir = (parentRight * forward) + (parentAt * -steer)
        end
    end

    if l_up then
        forceDir = forceDir + seatParent.shape.right
    end

    if l_down then
        forceDir = forceDir - seatParent.shape.right
    end

    if l_left then
        forceDir = forceDir - seatParent.shape.at
    end

    if l_right then
        forceDir = forceDir + seatParent.shape.at
    end
    --self.network:sendToClients("cl_visualise", { charDir, parentDir, forceDir })

    local bodyToRotate = parentShape:getBody()
    local creationMass = 0
    for v, k in pairs(self.shape:getBody():getCreationShapes()) do
        creationMass = creationMass + k:getBody():getMass()
    end

    local selectedMode = modes[self.sv.data.count]
    if selectedMode == modes[2] then
        forceDir.z = 0
    elseif selectedMode == modes[3] then
        forceDir.y = 0
        forceDir.x = 0
    elseif selectedMode == modes[4] then
        forceDir.y = 0
        forceDir.z = 0
        forceDir = parentDir * seatParent:getSteeringAngle()
    end

    sm.physics.applyTorque( bodyToRotate, forceDir * (creationMass / massDivider) * self.sv.data.slider, true )
    if not self.interactable.active then
        self:sv_updateState( { active = true, power = 1, index = 7 } )
    end
end

function Steer:sv_getLogicInputs()
    local l_active, l_left, l_right, l_up, l_down = nil, false, false, false, false
    for k, shape in pairs(self.interactable:getParents( sm.interactable.connectionType.logic )) do
        local colour = shape.shape.color
        if not isAnyOf(colour, l_inputColours) then
            l_active = shape
        elseif shape.active then
            --lets go more ifs
            if colour == l_inputColours[1] then
                l_up = true
            elseif colour == l_inputColours[2] then
                l_down = true
            elseif colour == l_inputColours[3] then
                l_right = true
            elseif colour == l_inputColours[4] then
                l_left = true
            end
        end
    end

    return l_active, l_left, l_right, l_up, l_down
end

function Steer:sv_updateState( args )
    self.interactable:setActive( args.active )
    self.interactable:setPower( args.power )

    self.network:sendToClients("cl_uvUpdate", args.index)
end

function Steer:sv_save()
    self.storage:save( self.sv.data )
    self.network:sendToClients("cl_updateData", self.sv.data)
end

function Steer:cl_uvUpdate( index )
    self.interactable:setUvFrameIndex( index )
end

function Steer:sv_changeControlMode()
    self.sv.data.controlMethodCount = self.sv.data.controlMethodCount < #controlModes and self.sv.data.controlMethodCount + 1 or 1
    self:sv_save()
end

function Steer:sv_changeCount( type )
    if type == "add" then
        self.sv.data.count = self.sv.data.count < #modes and self.sv.data.count + 1 or 1
    else
        self.sv.data.count = self.sv.data.count > 1 and self.sv.data.count - 1 or #modes
    end

    self:sv_save()
end



function Steer:client_onCreate()
    self.cl = {
        data = {},
        gui = sm.gui.createEngineGui()
    }

    self.cl.gui:setText( "Name", language_tag("CreationRotator_Title") )
	self.cl.gui:setText( "Interaction", language_tag("CreationRotator_Force") )
	self.cl.gui:setSliderCallback( "Setting", "cl_onSliderChange" )
	self.cl.gui:setIconImage( "Icon", obj_creationSteer )
end

function Steer:cl_refreshGUI()
    self.cl.gui:setSliderData( "Setting", maxForceMult + 1, self.cl.data.slider )
    self.cl.gui:setText( "SubTitle", language_tag("CreationRotator_Mult").. tostring( self.cl.data.slider ) )
end

function Steer:cl_onSliderChange( sliderName, sliderPos )
    self.cl.data.slider = sliderPos
    self:cl_refreshGUI()
    self.network:sendToServer("sv_onSliderChange", sliderPos)
end

function Steer:cl_updateData( data )
    self.cl.data = data
end

function Steer.client_getAvailableParentConnectionCount( self, connectionType )
	if bit.band( connectionType, sm.interactable.connectionType.logic ) ~= 0 then
		return 1 -- #self.interactable:getParents( sm.interactable.connectionType.logic )
	end
	if bit.band( connectionType, sm.interactable.connectionType.power ) ~= 0 then
		return 1 - #self.interactable:getParents( sm.interactable.connectionType.power )
	end
	return 0
end

function Steer:cl_visualise( dir )
    for v, k in pairs(dir) do
        sm.particle.createParticle( "paint_smoke", self.shape:getWorldPosition() + k, sm.quat.identity(), sm.color.new(v/10, v/10, v/10) )
    end
end

function Steer:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
	sm.gui.setInteractionText( o1..language_tag("CreationRotator_CurrentMode")..modes[self.cl.data.count]..language_tag("CreationRotator_CurrentInput")..controlModes[self.cl.data.controlMethodCount]..o2 )
    sm.gui.setInteractionText(
        sm.gui.getKeyBinding( "Use", true )..language_tag("Switch_mode"),
        sm.gui.getKeyBinding( "Tinker", true )..language_tag("CreationRotator_SwitchInput"),
        sm.gui.getKeyBinding( "Crawl", true ).." + "..sm.gui.getKeyBinding( "Use", true )..language_tag("CreationRotator_AdjustForce")
    )

    return true
end

function Steer:client_onInteract( char, lookAt )
    if lookAt then
        if char:isCrouching() then
            self:cl_refreshGUI()
            self.cl.gui:open()
        else
            self.network:sendToServer("sv_changeCount", "add")
            sm.audio.play("PaintTool - ColorPick")
        end
    end
end

function Steer:client_onTinker( char, lookAt )
    if lookAt then
        --self.network:sendToServer("sv_changeCount", "subtract")
        self.network:sendToServer("sv_changeControlMode")
        sm.audio.play("PaintTool - ColorPick")
    end
end