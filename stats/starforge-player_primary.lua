preStarforge_applyDamageRequest = applyDamageRequest

function applyDamageRequest(damageRequest)
  world.sendEntityMessage(entity.id(), "starforge-lastDamageConfig", damageRequest)

  local oldDamageRequest = damageRequest
  if preStarforge_applyDamageRequest then
    damageRequest = preStarforge_applyDamageRequest(damageRequest)
  end

  --Calculate damageResistance
  if status.resource("starforgeDamageResistance") and damageRequest[1] and damageRequest[1].damage then
    damageRequest[1].damage = damageRequest[1].damage * (status.resource("starforgeDamageResistance") - 1)
  end

  return damageRequest
end