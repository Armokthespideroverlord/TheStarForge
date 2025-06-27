require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  if not storage.seed then
    storage.seed = getSeed()
  end
  self.guiConfig = config.getParameter("guiConfig")
  object.setInteractive(true)

  storage.storedStock = storage.storedStock
  
  message.setHandler("starforge-updateVendingStock", function(_, _, newStock)
    storage.storedStock = newStock
  end)
  message.setHandler("starforge-refreshStock", function(_, _, newStock)
    storage.seed = getSeed()
    return {
      newSeed = storage.seed,
      refreshTime = storage.lastTime + (config.getParameter("resetInterval", 30) * 60)
    }
  end)
end

function onInteraction(args)
  if (storage.lastTime + (config.getParameter("resetInterval", 30) * 60)) < os.time() then
    storage.seed = getSeed()
  end

  self.guiConfig.seed = storage.seed
  self.guiConfig.storedStock = storage.storedStock
  self.guiConfig.refreshTime = storage.lastTime + (config.getParameter("resetInterval", 30) * 60)

  return {"ScriptPane", self.guiConfig}
end

function getSeed()
  --math.randomseed(util.seedTime())
  storage.lastTime = os.time()
  return math.random(1, 4294967295)
end