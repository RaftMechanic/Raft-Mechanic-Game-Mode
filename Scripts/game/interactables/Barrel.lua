---@class Barrel : ShapeClass
Barrel = class()

Barrel.lootTable = {
  { uuid = blk_scrapwood, quantity = 4, bp = "$CONTENT_DATA/LocalBlueprints/junk1.blueprint" },
  { uuid = blk_plastic, quantity = 6, bp = "$CONTENT_DATA/LocalBlueprints/junk2.blueprint" },
  { uuid = obj_consumable_gas, quantity = function() return math.random(2, 5) end },
  { uuid = obj_consumable_fertilizer, quantity = function() return math.random(2, 5) end },
  { uuid = obj_consumable_water, quantity = function() return math.random(2, 5) end, colour = sm.color.new(1, 1, 1) },
  { uuid = obj_consumable_sunshake, quantity = 1 }
}
Barrel.minLoot = 3
Barrel.maxLoot = 6

function Barrel:server_onMelee()
  self:sv_dropItems()
end

function Barrel:server_onProjectile()
  self:sv_dropItems()
end

function Barrel:server_onExplosion()
  self:sv_dropItems()
end

--[[
function Barrel.server_onCollision( self, other, position, selfPointVelocity, otherPointVelocity, normal )
    if isAnyOf(type(other), { "Body", "Shape" }) and other:getVelocity():length2() >= 25 then
        self:sv_dropItems()
    end
end
]]

function Barrel:sv_dropItems()
  local loot = {}
  for _ = 1, math.random(self.minLoot, self.maxLoot) do
    loot[#loot + 1] = self.lootTable[math.random(#self.lootTable)]
  end

  local pos = self.shape.worldPosition
  for _, item in pairs(loot) do
    if sm.item.isBlock(item.uuid) then
      sm.creation.importFromFile(self.shape.body:getWorld(), item.bp, pos)
    else
      local shape = sm.shape.createPart(
        item.uuid,
        pos,
        sm.quat.identity(),
        true,
        true
      )

      if item.uuid ~= obj_consumable_sunshake then
        shape.stackedAmount = item.quantity()
      end

      if item.colour then
        shape.color = item.colour
      end
    end
  end

  sm.effect.playEffect("Tree - BreakTrunk Pine", pos)
  self.shape:destroyShape(0)
end
