-- Melee primary ability
StarforgeMeleeCombo = WeaponAbility:new()

function StarforgeMeleeCombo:init()
  self.comboStep = 1
  animator.setGlobalTag("comboDirectives", "")

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns()

  self.weapon:setStance(self.stances.idle)

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.animKeyPrefix = self.animKeyPrefix or ""

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function StarforgeMeleeCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  world.debugText(self.cooldownTimer, vec2.add(mcontroller.position(), {0, 1}), "red")
  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end

  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

-- State: windup
function StarforgeMeleeCombo:windup()
  local stance = self.stances["windup"..self.comboStep]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  if stance.teleport then
    local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
    animator.setAnimationState("swoosh", animStateKey)
    animator.playSound(animStateKey)

    local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
    animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  end
  
  -- Optionally flash the weapon
  if stance.flashTime then
    self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
    activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0

  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    local windupSwing = {}
    if stance.windupSwing ~= false or stance.windupSwing ~= 0 then
      local windupSwingValue = stance.windupSwing or 0.1
      local fireStance = self.stances["fire"..self.comboStep]
      windupSwing.armRotation = (stance.armRotation - fireStance.armRotation) * windupSwingValue
      windupSwing.weaponRotation = (stance.weaponRotation - fireStance.weaponRotation) * windupSwingValue
    end
    
    local progress = 0
    util.wait(stance.duration, function()
      if stance.windupSwing ~= false then
        for part, rotation in pairs(windupSwing) do
          local from = stance[part]
          local to = stance[part] + rotation
        
          self.weapon["relative" .. part:gsub("^%l", string.upper)] = util.toRadians(util.interpolateHalfSigmoid(1- progress, from, to))
        end
        progress = math.min(1.0, progress + (self.dt / stance.duration))
      end
    end)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if stance.teleport then
    self:setState(self.teleport)
  elseif self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function StarforgeMeleeCombo:teleport()
  local stance = self.stances["fire"..self.comboStep]
  
  --Create the teleportation effect and add 0.5 for both animations to take effect
  status.addEphemeralEffect(stance.teleportStatus or "starforge-teleporteffect", stance.duration + 0.5)

  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local oldPosition = mcontroller.position()
  local targetPosition = vec2.add(oldPosition, vec2.rotate({mcontroller.facingDirection() * stance.teleportTarget[1], stance.teleportTarget[2]}, self.weapon.aimAngle * mcontroller.facingDirection()))

  local groundCollision = world.lineTileCollisionPoint(mcontroller.position(), targetPosition)
  if groundCollision then
    local groundPos, normal = groundCollision[1], groundCollision[2]
    targetPosition = groundPos
  end
	
  local targets = world.entityQuery(mcontroller.position(), stance.forgivenessRange, {
    withoutEntityId = activeItem.ownerEntityId(),
    includedTypes = {"creature"},
    order = "nearest"
  })
  if targets[1] and entity.entityInSight(targets[1]) and world.entityCanDamage(activeItem.ownerEntityId(), targets[1]) then
	targetPosition = world.entityPosition(targets[1])
  end
  world.resolvePolyCollision(mcontroller.collisionPoly(), vec2.add(targetPosition, stance.teleportOffset), stance.teleportTolerance)

  --Allow first teleport effect to take place
  util.wait(0.25)
  
  if stance.projectileType and targetPosition then
	local angleToTarget = vec2.angle({targetPosition[2] - mcontroller.position()[2], targetPosition[1] - mcontroller.position()[1]})
	local aimVector = vec2.rotate({0, 1}, -angleToTarget)
	--aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	
	local params = stance.projectileParameters or {}
	params.power = stance.projectileDamage * config.getParameter("damageLevelMultiplier")
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.speed = util.randomInRange(params.speed)
		
    world.spawnProjectile(
	  stance.projectileType,
	  targetPosition,
	  activeItem.ownerEntityId(),
	  aimVector,
	  false,
	  params
	)
  end
  
  util.wait(stance.duration, function()
    --Reset player momentum, prevents fall damage
    mcontroller.setXVelocity(0, 0)
    mcontroller.setYVelocity(0, 0)
    mcontroller.setPosition(targetPosition)
  end)
  animator.setGlobalTag("comboDirectives", "")
  
  mcontroller.setPosition(oldPosition)

  if stance.continueStep then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

-- State: wait
-- waiting for next combo input
function StarforgeMeleeCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  
  -- Optionally flash the weapon
  if stance.flashTime then
    self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
    activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)

  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)

  animator.setGlobalTag("comboDirectives", "")
  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function StarforgeMeleeCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function StarforgeMeleeCombo:fire()
  local stance = self.stances["fire"..self.comboStep]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  
  -- Optionally flash the weapon
  if stance.flashTime then
    self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
    activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire" .. self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  -- If this step is configured as a "spin" move, spin the weapon
  if stance.spinRate then
    util.wait(stance.duration, function()
      local damageArea = partDamageArea("swoosh")
      self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
    
      -- Remove the weapon from the player's hand, allowing it to rotate freely
      activeItem.setOutsideOfHand(true)
    
      -- Spin the weapon
      self.weapon.relativeWeaponRotation = self.weapon.relativeWeaponRotation + util.toRadians(stance.spinRate * self.dt)
    
      -- Optionally force the player to walk while in this stance
      if stance.forceWalking then
        mcontroller.controlModifiers({runningSuppressed=true})
      end
      
      -- Optionally freeze the player in place if so configured
      if stance.freezePlayer then
       mcontroller.setVelocity({0,0})
      end
    end)
    animator.setAnimationState("swoosh", "idle")
  -- If this step is a regular attack, simply set the damage area for the duration of the step
  else
    local overSwing = {}
    if stance.overSwing ~= false or stance.overSwing ~= 0 then
      local overSwingValue = stance.overSwing or 0.1
      local windupStance = self.stances["windup"..self.comboStep]
      overSwing.armRotation = (stance.armRotation - windupStance.armRotation) * overSwingValue
      overSwing.weaponRotation = (stance.weaponRotation - windupStance.weaponRotation) * overSwingValue
    end
    
    local progress = 0
    util.wait(stance.duration, function()
      local damageArea = partDamageArea("swoosh")
      self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
      
      --Optionally freeze the player in place if so configured
      if stance.freezePlayer then
        mcontroller.setVelocity({0,0})
      end
    
      if stance.overSwing ~= false or stance.overSwing ~= 0 then
        for part, rotation in pairs(overSwing) do
          local from = stance[part]
          local to = stance[part] + rotation
        
          self.weapon["relative" .. part:gsub("^%l", string.upper)] = util.toRadians(util.interpolateHalfSigmoid(progress, from, to))
        end
        progress = math.min(1.0, progress + (self.dt / stance.duration))
      end
    end)
  end
  
  if stance.continueStep then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    animator.setGlobalTag("comboDirectives", "")
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
    
    local alt = getAltAbility()
    if alt and self.altComboFinisher then
      triggerFinisher(self.finisherHoldTime)
    end
  end
end

function StarforgeMeleeCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function StarforgeMeleeCombo:animatedFlash(flashTime, flashDirectives)
  animator.setGlobalTag("bladeDirectives", flashDirectives)
  self.flashTimer = flashTime or self.flashTime
end

function StarforgeMeleeCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function StarforgeMeleeCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(self.stepDamageConfig[i], copy(self.damageConfig)) --swapped for testing?
    self.stepDamageConfig[i].timeoutGroup = "primary" .. i
    if self.stepDamageConfig[i].statusEffects ~= self.damageConfig.statusEffects then --can't copy empty tables ig?
      self.stepDamageConfig[i].statusEffects = self.damageConfig.statusEffects
    end

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (totalAttackTime - attackTime) * speedFactor)
  end
end

function StarforgeMeleeCombo:uninit()
  self.weapon:setDamage()
end

