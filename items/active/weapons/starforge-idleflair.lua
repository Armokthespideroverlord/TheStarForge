local starforge_animationFlair_init = init
function init() starforge_animationFlair_init()
    animationFlairConfig = config.getParameter("animationFlairConfig", {})
    resetAnimationFlairTimer()
end

starforge_animationFlair_update = update
function update(dt, fireMode, shiftHeld) starforge_animationFlair_update(dt, fireMode, shiftHeld)
    animationFlairConfig.timer = math.max(0, animationFlairConfig.timer - dt)
    if animationFlairConfig.timer <= 0 then
        playFlair()
    end
end

function resetAnimationFlairTimer()
    animationFlairConfig.timer = ((animationFlairConfig.interval[2] - animationFlairConfig.interval[1]) * math.random()) + animationFlairConfig.interval[1]
end

function playFlair()
    local variant = math.random(1, animationFlairConfig.variants)
    animator.setGlobalTag(animationFlairConfig.flairTag, variant)
    animator.setAnimationState(animationFlairConfig.animationPart, animationFlairConfig.animationState)
    resetAnimationFlairTimer()
end