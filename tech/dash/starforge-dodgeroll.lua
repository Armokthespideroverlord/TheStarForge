require "/tech/doubletap.lua"
require "/scripts/starforge-util.lua"

function init()
  nebUtil.getParameters({"dodgeVelocity", "minRollVelocity", "maxRollVelocity", "endRollVelocity", "rollVelocityDegradeFactor", "fallVelocityFactor", "rollDuration", "maximumRolls", "rollOffset", "minimumFallVelocity", "rollMovementParameters"})
	
  self.rollingJumpTime = config.getParameter("rollingJumpTime", 0.25)
  self.rollingJumpModifier = config.getParameter("rollingJumpModifier", 1.5)
  self.forceDeactivateTime = config.getParameter("forceDeactivateTime", 3.0)
  self.forceDeactivateDirectives = config.getParameter("forceDeactivateDirectives", "?fade=FF0000")
  
  self.basePoly = mcontroller.baseParameters().standingPoly		--Gets and saves the player's standing poly for later use
  self.collisionSet = {"Null", "Block", "Dynamic", "Slippery"}	--Saves a list of collision types to check for when trying to resolve player position
  
  self.rolling = false
  self.rollDirection = 1
  self.rollTimer = 0
  self.forceDeactivateTimer = 0
  self.rollCounter = 0
  self.rollVelocity = 0
  self.facingDirection = 1
  self.lastDirection = 1
  self.wasOnGround = false
  self.lastFallVelocity = 0
  self.rollingJumpTimer = 0
  
  self.doubleTap = DoubleTap:new({"left", "right"}, config.getParameter("maximumDoubleTapTime"), function(dashKey)
      if not self.rolling
          and mcontroller.onGround() then

	    self.rollVelocity = mcontroller.baseParameters().runSpeed + self.dodgeVelocity
        startRoll(dashKey == "left" and -1 or 1)
      end
    end)
  
  --Reset everything to prevent visual errors
  tech.setParentOffset({0,0})
  tech.setParentState()
  tech.setParentDirectives()
  animator.setParticleEmitterActive("rollParticlesRight", false)
  animator.setParticleEmitterActive("rollParticlesLeft", false)
  mcontroller.setRotation(0)
end

function uninit()
  animator.setParticleEmitterActive("rollParticlesRight", false)
  animator.setParticleEmitterActive("rollParticlesLeft", false)
  status.clearPersistentEffects("movementAbility")
  status.removeEphemeralEffect("invulnerable")
  tech.setParentState()
  tech.setParentOffset({0,0})
  tech.setParentDirectives()
  mcontroller.setRotation(0)
end

function update(args)
  self.doubleTap:update(args.dt, args.moves)
  --========================= ROLL BEHAVIOUR =========================
  --Determine the intended roll direction
  if args.moves["left"] then
	self.lastDirection = -1
  elseif args.moves["right"] then
	self.lastDirection = 1
  elseif self.wasOnGround then
	self.lastDirection = mcontroller.facingDirection()
  end
  
  --If falling and holding [down], check for ground contact
  if self.lastFallVelocity <= self.minimumFallVelocity and args.moves["down"] and not self.rolling and not status.statPositive("activeMovementAbilities") then
	status.addEphemeralEffect("falldamageprotectionweak")
	
	--If we touched the ground but weren't grounded on the last frame, go into roll state. Also calculate intended roll velocity
	if mcontroller.onGround() and not self.wasOnGround then
	  local startingVelocity = math.max(math.abs(self.lastFallVelocity), math.abs(mcontroller.xVelocity())) * self.fallVelocityFactor
	  self.rollVelocity = math.min(math.max(self.minRollVelocity, startingVelocity), self.maxRollVelocity)
	  startRoll(self.lastDirection)
	end
  end
  
  --If we started rolling, update player rotation and roll status here
  if self.rolling then
	mcontroller.controlModifiers({movementSuppressed = true}) --Suppress player movement since the tech will handle movement manually
	mcontroller.controlParameters(self.rollMovementParameters) --Change player poly to rolling poly
	mcontroller.controlFace(self.facingDirection)
    animator.setFlipped(mcontroller.facingDirection() == -1)
	
	--Rotate and move the player, and keep the rolling jump timer up
	mcontroller.setRotation(-math.pi * 2 * self.rollDirection * (-self.rollTimer / self.rollDuration))
	mcontroller.setXVelocity(self.rollVelocity * self.rollDirection)
	self.rollingJumpTimer = self.rollingJumpTime
	
	--Use sine and cosine functions to correct player offset because our movement controller's origin point has changed
	local rollPeriod = self.rollDuration / (2 * math.pi)
	local rollSine = self.rollOffset * math.sin(self.rollTimer / rollPeriod)
	local rollCos = self.rollOffset * math.cos(self.rollTimer / rollPeriod)
	tech.setParentOffset({(rollSine * -self.rollDirection), rollCos})
	
	--Activate and deactivate particles based on facing direction and roll direction
	if self.rollDirection == 1 and self.facingDirection == 1 then
	  animator.setParticleEmitterActive("rollParticlesLeft", true)
	  animator.setParticleEmitterActive("rollParticlesRight", false)
	elseif self.rollDirection == 1 and self.facingDirection == -1 then
	  animator.setParticleEmitterActive("rollParticlesRight", true)
	  animator.setParticleEmitterActive("rollParticlesLeft", false)
	elseif self.rollDirection == -1 and self.facingDirection == 1 then
	  animator.setParticleEmitterActive("rollParticlesRight", true)
	  animator.setParticleEmitterActive("rollParticlesLeft", false)
	elseif self.rollDirection == -1 and self.facingDirection == -1 then
	  animator.setParticleEmitterActive("rollParticlesLeft", true)
	  animator.setParticleEmitterActive("rollParticlesRight", false)
	end
	
	--Advance roll timer and degrade roll velocity
    self.rollTimer = math.max(0, self.rollTimer - args.dt)
	self.rollVelocity = math.max(self.endRollVelocity, self.rollVelocity - (args.dt * self.rollVelocityDegradeFactor))
	
	--End the roll normally or continue it based on input and roll cycles completed
    if (self.rollTimer == 0 or self.rollCounter > 1) and not args.moves["down"] then
      endRoll(false)
	--End the roll if we started falling or have completed our max number of roll cycles
	elseif (self.rollCounter > 1 and mcontroller.falling()) or self.rollCounter > self.maximumRolls then
	  endRoll(false)
	end
	
	--Reset the roll timer when it's at zero to start a new cycle
	if self.rollTimer == 0 then
	  self.rollTimer = self.rollDuration
	  self.rollCounter = self.rollCounter + 1
	end
	
	--If we are at max rolls, allow switching of roll direction
	if args.moves["right"] and self.rollCounter > self.maximumRolls then
	  self.rollDirection = 1
	elseif args.moves["left"] and self.rollCounter > self.maximumRolls then
	  self.rollDirection = -1
	end
	
	--If we've been rolling for a while and are holding down [jump], force the roll to end
	if args.moves["jump"] and self.rollCounter > self.maximumRolls then
	  if self.forceDeactivateTimer == 0 then
		animator.playSound("forceDeactivate", -1)
	  end
	  self.forceDeactivateTimer = math.min(self.forceDeactivateTime, self.forceDeactivateTimer + args.dt)
	  tech.setParentDirectives(self.forceDeactivateDirectives.."="..self.forceDeactivateTimer / self.forceDeactivateTime * 0.85) --Fade the player to a preset colour based on deactivation progress
	  if self.forceDeactivateTimer == self.forceDeactivateTime then
		endRoll(true)
	  end
	else
	  self.forceDeactivateTimer = 0
	  tech.setParentDirectives()
	  animator.stopAllSounds("forceDeactivate")
	end
  end
  
  --========================= MISC BEHAVIOUR =========================
  self.wasOnGround = mcontroller.onGround()
  self.lastFallVelocity = mcontroller.yVelocity()
end

--===================================================================================================
-- ROLL FUNCTIONS
--===================================================================================================
--Starts the roll sequence and stops tool usage. Roll must be reset with endRoll() to prevent issues!
function startRoll(direction)	
  self.rollDirection = direction
  self.rollTimer = self.rollDuration
  self.facingDirection = mcontroller.facingDirection()
  self.rolling = true
  
  self.rollCounter = 1
  
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  tech.setToolUsageSuppressed(true)
  tech.setParentState("Duck")
  
  animator.playSound("startRoll")
end

--Attempts to correctly end the roll sequence
function endRoll(forceEndRoll)
  local pos = false
  pos = restorePosition()
  
  --Only exit roll state if we can transform or are forced to end our roll
  if pos or forceEndRoll then
	if pos then
	  mcontroller.setPosition(pos)
	end
	
	mcontroller.setRotation(0)
	
	animator.setParticleEmitterActive("rollParticlesRight", false)
	animator.setParticleEmitterActive("rollParticlesLeft", false)
	animator.stopAllSounds("forceDeactivate")
	
	self.rolling = false
	self.rollCounter = 0
	self.rollTimer = 0
	self.rollVelocity = 0
	
	tech.setParentState()
	tech.setToolUsageSuppressed(false)
	tech.setParentOffset({0,0})
	tech.setParentDirectives()
	
	status.clearPersistentEffects("movementAbility")
  end
end

--===================================================================================================
-- TRANSFORM FUNCTIONS
--===================================================================================================
--Function to resolve player position when entering the roll state
function transformPosition(pos)
  pos = pos or mcontroller.position()
  local groundPos = world.resolvePolyCollision(self.rollMovementParameters.collisionPoly, {pos[1], pos[2] - positionOffset()}, 1, self.collisionSet)
  if groundPos then
    return groundPos
  else
    return world.resolvePolyCollision(self.rollMovementParameters.collisionPoly, pos, 1, self.collisionSet)
  end
end

--Function to resolve player position after exiting a roll
function restorePosition(pos)
  pos = pos or mcontroller.position()
  local groundPos = world.resolvePolyCollision(self.basePoly, {pos[1], pos[2] + positionOffset()}, 1, self.collisionSet)
  if groundPos then
    return groundPos
  else
    return world.resolvePolyCollision(self.basePoly, pos, 1, self.collisionSet)
  end
end

--Calculates the height offset between the player's standing poly and the rolling poly
function positionOffset()
  return minY(self.rollMovementParameters.collisionPoly) - minY(self.basePoly)
end

--Gets the lowest point (as a float/y coordinate) of the given poly
function minY(poly)
  local lowest = 0
  for _,point in pairs(poly) do
    if point[2] < lowest then
      lowest = point[2]
    end
  end
  return lowest
end

