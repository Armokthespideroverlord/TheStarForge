StarForgeBloodEmpowerment = WeaponAbility:new()

function StarForgeBloodEmpowerment:init()
  self.cooldownTimer = self.cooldownTime

  self.active = false
end

function StarForgeBloodEmpowerment:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.active and not status.overConsumeResource("health", self.healthPerSecond * self.dt) then
    self.active = false
  end

  if fireMode == "alt"
      and not self.weapon.currentAbility
      and self.cooldownTimer == 0
      and not status.resourceLocked("health") then

    if self.active then
      self:setState(self.windup)
    else
      self:setState(self.empower)
    end
  end
end

function StarForgeBloodEmpowerment:empower()
  self.weapon:setStance(self.stances.empower)

  util.wait(self.stances.empower.durationBefore)

  animator.playSound("empower")
  self.active = true

  util.wait(self.stances.empower.durationAfter)
end

function StarForgeBloodEmpowerment:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function StarForgeBloodEmpowerment:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  local position = vec2.add(mcontroller.position(), {self.projectileOffset[1] * mcontroller.facingDirection(), self.projectileOffset[2]})
  local params = {
    powerMultiplier = activeItem.ownerPowerMultiplier(),
    power = self:damageAmount()
  }
  world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), self:aimVector(), false, params)

  animator.playSound("slash")
  status.overConsumeResource("energy", status.resourceMax("energy"))
  self.active = false

  util.wait(self.stances.fire.duration)

  self.cooldownTimer = self.cooldownTime
end

function StarForgeBloodEmpowerment:uninit()

end

function StarForgeBloodEmpowerment:aimVector()
  return {mcontroller.facingDirection(), 0}
end

function StarForgeBloodEmpowerment:damageAmount()
  return self.baseDamage * config.getParameter("damageLevelMultiplier")
end
