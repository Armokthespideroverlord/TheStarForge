-- Melee primary ability
StarforgeMeleeSlash = WeaponAbility:new()

function StarforgeMeleeSlash:init()
  self.damageConfig.baseDamage = self.baseDamage or self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0

  self.cooldownTimer = self:cooldownTime()
end

-- Ticks on every update regardless if this is the active ability
function StarforgeMeleeSlash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

-- State: windup
function StarforgeMeleeSlash:windup()
  self.weapon:setStance(self.stances.windup)

  if self.stances.windup.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(self.stances.windup.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances.preslash then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: preslash
-- brief frame in between windup and fire
function StarforgeMeleeSlash:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function StarforgeMeleeSlash:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState((self.activatingFireMode or self.abilitySlot) .. "Swoosh", "fire")
  animator.playSound(self.fireSound or (self.activatingFireMode or self.abilitySlot) .. "Fire")
  animator.burstParticleEmitter((self.activatingFireMode or self.abilitySlot) .. "Swoosh")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea((self.activatingFireMode or self.abilitySlot) .. "Swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  self.cooldownTimer = self:cooldownTime()
end

function StarforgeMeleeSlash:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function StarforgeMeleeSlash:uninit()
  self.weapon:setDamage()
end
