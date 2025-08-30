local starforge_hangingParts_init = init
function init() starforge_hangingParts_init()
    self.hangingParts = config.getParameter("hangingParts")
    self.shakeVelocity = config.getParameter("shakeVelocity", 1)

    self.currentRotation = 0
    self.graceTime = 0
    self.rotationMemory = self.currentRotation
    self.shakeDirection = 1
    self.lastBaseFactor = vec2.norm(mcontroller.velocity())
end

starforge_hangingParts_update = update
function update(dt, fireMode, shiftHeld) starforge_hangingParts_update(dt, fireMode, shiftHeld)
    self.graceTime = math.min(math.pi/2, self.graceTime)
    self.graceTime = math.max(0, self.graceTime - dt)

    local baseFactor = vec2.norm(mcontroller.velocity())
    if mcontroller.walking() then
        baseFactor[1] = baseFactor[1] * 0.5
    end
    local targetRotation = (baseFactor[1] * -0.75) * mcontroller.facingDirection()
    
    if self.weapon.currentAbility then
        targetRotation = targetRotation - (self.weapon.relativeArmRotation * 2)
        self.graceTime = 5 * math.pi / self.shakeVelocity
        self.shakeDirection = 1
    end

    if self.graceTime > 0 then
        targetRotation = ((self.graceTime * 0.5) * math.sin(self.graceTime * (self.shakeVelocity))) * self.shakeDirection
    end
    
    self.currentRotation = self.rotationMemory + (targetRotation - self.rotationMemory) * (dt * 7)
    self.rotationMemory = self.currentRotation
    
    for tgroup, anchor in pairs(self.hangingParts) do
        animator.resetTransformationGroup(tgroup)

        local finalRotation = (self.currentRotation) - (self.weapon.relativeWeaponRotation + self.weapon.relativeArmRotation)
        animator.rotateTransformationGroup(tgroup, finalRotation, animator.partPoint(anchor, "rotationCenter"))
    end

    if mcontroller.running() or mcontroller.walking() then
        self.graceTime = 0
    end
    
    if not mcontroller.running() and not mcontroller.walking() and self.lastBaseFactor[1] ~= 0 and (math.abs(self.currentRotation - self.rotationMemory) < math.pi / 5 or math.abs(self.currentRotation - self.rotationMemory) > -0.05) and self.graceTime == 0 then
        self.graceTime = 2 * math.pi / self.shakeVelocity
	    self.shakeDirection = -baseFactor[1] * mcontroller.facingDirection()
    end
    
    self.lastBaseFactor = baseFactor
end