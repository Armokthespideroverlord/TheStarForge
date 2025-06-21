StarForgeActivateBlade = WeaponAbility:new()

function StarForgeActivateBlade:init()
  self.cooldownTimer = self.cooldownTime

  self.active = false
end

function StarForgeActivateBlade:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.active and not status.overConsumeResource("energy", self.energyPerSecond * self.dt) then
    self.active = false
  end

  if fireMode == "alt"
      and not self.weapon.currentAbility
      and self.cooldownTimer == 0
      and not status.resourceLocked("energy") then

      self:setState(self.empower)
  end
end

function StarForgeActivateBlade:empower()
  util.wait(self.durationBefore)

  animator.playSound("empower")
  self.active = (not self.active)
  if not self.active and self.projectileType then
    self:setState(self.windup)
  end

  util.wait(self.durationAfter)
  self.cooldownTimer = self.cooldownTime
end

function StarForgeActivateBlade:windup()
  self.weapon:setStance(self.stances.windup)
  animator.setGlobalTag("comboDirectives", self.stances.windup.comboDirectives or "")
  self.weapon:updateAim()

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function StarForgeActivateBlade:fire()
  self.weapon:setStance(self.stances.fire)
  animator.setGlobalTag("comboDirectives", self.stances.fire.comboDirectives or "")
  self.weapon:updateAim()

  self:fireProjectile(burstNumber)

  animator.playSound("altSlash")
  if self.swooshAnim then
    animator.setAnimationState("swoosh", self.swooshAnim)
  end

  util.wait(self.stances.fire.duration)
  animator.setGlobalTag("comboDirectives", "")
  self.cooldownTimer = self.cooldownTime
end

function StarForgeActivateBlade:fireProjectile(burstNumber)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()

  local projectileType = self.projectileType
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end
  
  local shotNumber = 0

  local baseSpeed = params.speed
  local baseTTL = params.timeToLive
  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount or 1) do
    if baseTTL then
      params.timeToLive = util.randomInRange(baseTTL)
    end
    if baseSpeed then
      params.speed = util.randomInRange(baseSpeed)
    end
	
    shotNumber = i

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy or 0, shotNumber, burstNumber),
        self.trackSourceEntity or false,
        params
      )
  end
  return projectileId
end

function StarForgeActivateBlade:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset or {0, 0}))
end

function StarForgeActivateBlade:damagePerShot()
  return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / (self.projectileCount or 1)
end

function StarForgeActivateBlade:aimVector(inaccuracy, shotNumber, burstNumber)
  local angleAdjustmentList = self.angleAdjustmentsPerShot or {}

  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy or 0, 0) + (angleAdjustmentList[shotNumber] or 0) + ((burstNumber or 0) * (util.toRadians(self.stances.fire.armRotation * 0.15) or 0)))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarForgeActivateBlade:uninit()
end