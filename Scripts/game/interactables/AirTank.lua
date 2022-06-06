dofile("$CONTENT_DATA/Scripts/game/raft_items.lua")

AirTank = class()
AirTank.maxParentCount = 1
AirTank.maxChildCount = 0
AirTank.connectionInput = sm.interactable.connectionType.logic
AirTank.connectionOutput = sm.interactable.connectionType.none
AirTank.colorNormal = sm.color.new( 0x00ccccff )
AirTank.colorHighlight = sm.color.new( 0x00ffffff )

function AirTank:server_onFixedUpdate(dt)
	local parent = self.interactable:getSingleParent()
	local shape = self.shape
	if parent then
		if parent.active and shape.uuid == obj_airtank_empty then
			shape:replaceShape(obj_airtank_full)
		elseif not parent.active and shape.uuid == obj_airtank_full then
			shape:replaceShape(obj_airtank_empty)
		end
	elseif shape.uuid == obj_airtank_full then
		shape:replaceShape(obj_airtank_empty)
	end

	if self.shape.uuid ~= obj_airtank_empty then return end
	sm.physics.applyImpulse( self.shape, sm.vec3.new(0,0,-1) * 25, true)
end

function AirTank:client_canInteract()
	return false
end