require "/scripts/c5easing.lua"

-- Melee primary ability
StarforgeMeleeSlash = WeaponAbility:new()

function StarforgeMeleeSlash:init()
  self.damageConfig.baseDamage = self.baseDamage or self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0

  self.transition = self.stances.transitionState

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
  local stance = self.stances.fire

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  animator.resetTransformationGroup("swoosh")
  animator.rotateTransformationGroup("swoosh", (self.stances.fire.swooshRotation or 0) * math.pi/180)
  animator.setAnimationState((self.activatingFireMode or self.abilitySlot) .. "Swoosh", "fire")
  animator.playSound(self.fireSound or (self.activatingFireMode or self.abilitySlot) .. "Fire")
  animator.burstParticleEmitter((self.activatingFireMode or self.abilitySlot) .. "Swoosh")
  
  local overSwing = {}
  if stance.overSwing ~= false then
    local overSwingValue = 0.05
    local windupStance = self.stances.windup
    overSwing.armRotation = (stance.armRotation - windupStance.armRotation) * overSwingValue
    overSwing.weaponRotation = (stance.weaponRotation - windupStance.weaponRotation) * overSwingValue
  end

  local progress = 0
  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea((self.activatingFireMode or self.abilitySlot) .. "Swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
    
    if stance.overSwing ~= false then
      for part, rotation in pairs(overSwing) do
        local from = stance[part]
        local to = stance[part] + rotation
      
        self.weapon["relative" .. part:gsub("^%l", string.upper)] = util.toRadians(util.interpolateHalfSigmoid(progress, from, to))
      end
      progress = math.min(1.0, progress + (self.dt / stance.duration))
    end
  end)

  if self.transition then
    self:setState(self.transitionState)
  else
    self.cooldownTimer = self:cooldownTime()
  end
end

function StarforgeMeleeSlash:transitionState()
  self.weapon:setStance(self.stances.transitionState)
  self.weapon:updateAim()

  if animator.hasSound("transitionState") then
    animator.playSound("transitionState")
  end

  local progress = 0
  util.wait(self.stances.transitionState.duration, function()
    local from = self.stances.transitionState.weaponOffset or {0,0}
    local to = self.weapon.abilities[1].stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {c5Easing.easeOut(progress, from[1], to[1]), c5Easing.easeOut(progress, from[2], to[2])}
	
    self.weapon.relativeWeaponRotation = util.toRadians(c5Easing.easeInOut(progress, self.stances.transitionState.weaponRotation, self.weapon.abilities[1].stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(c5Easing.easeOut(progress, self.stances.transitionState.armRotation, self.weapon.abilities[1].stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.transitionState.duration))
  end)
  
  self.cooldownTimer = self:cooldownTime()
  return
end

function StarforgeMeleeSlash:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function StarforgeMeleeSlash:uninit()
  self.weapon:setDamage()
end
