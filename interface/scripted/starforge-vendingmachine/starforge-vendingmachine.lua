require "/scripts/util.lua"

function init()
  self.itemList = "itemScrollArea.itemList"
  self.totalCost = "lblCostTotal"
  self.refreshTimer = "lblRefreshTimer"

  self.weaponType = config.getParameter("weaponType", "starforge-combatrifle")
  self.itemParameters = config.getParameter("itemParameters", {})
  self.weaponInventorySize = config.getParameter("weaponInventorySize", 5)

  self.refreshTime = config.getParameter("refreshTime", 0)
 
  refreshSeeds(config.getParameter("seed", 1))
  
  self.selectedItem = nil

  self.weaponTier = config.getParameter("weaponTier")

  populateItemList(true, config.getParameter("storedStock"))
end

function update(dt)
  if self.activePromise and self.activePromise:finished() then
    local result = self.activePromise:result()
    self.refreshTime = result.refreshTime
    refreshSeeds(result.newSeed)
    populateItemList(true)

    self.activePromise = nil
  end

  populateItemList()

  if self.refreshTime < os.time() then
    self.activePromise = world.sendEntityMessage(pane.sourceEntity(), "starforge-refreshStock")
  end
  widget.setText(self.refreshTimer, "Refresh in:\n" .. toTime(self.refreshTime - os.time()))
end

function populateItemList(forceRepop, storedStock)
  local playerMoney = player.currency("money")

  if forceRepop then
    widget.clearListItems(self.itemList)

    local showEmptyLabel = true

    self.currentStock = {}
    for i = 1, self.weaponInventorySize do
      local generatedWeapon
      if storedStock then
        generatedWeapon = storedStock[i]
      else
        generatedWeapon = root.createItem({name = self.weaponType, parameters = self.itemParameters}, calculateTier(self.weaponTier or world.threatLevel()), self.seeds[i])
      end
      table.insert(self.currentStock, generatedWeapon)
      --local randomWeapon = self.weaponTypes[(math.random(1, 4294967295) % #self.weaponTypes) + 1]
      --root.itemConfig(randomWeapon)
      local config = generatedWeapon.parameters 

      showEmptyLabel = false

      local listItem = string.format("%s.%s", self.itemList, widget.addListItem(self.itemList))
      local name = config.shortdescription or config.shortdescription or "Failed to reach item name"
      local cost = config.price or 1

      widget.setItemSlotItem(string.format("%s.itemIcon", listItem), generatedWeapon)
      widget.setText(string.format("%s.itemName", listItem), name)
      
      widget.setText(string.format("%s.priceLabel", listItem), config.locked and "Sold!" or cost)
      
      widget.setVisible(string.format("%s.unavailableoverlay", listItem), config.locked or cost > playerMoney)
      
      widget.setData(listItem,
        {
          item = generatedWeapon,
          index = i
        }
      )
    end

    self.selectedItem = nil
    showWeapon(nil)
    
    world.sendEntityMessage(pane.sourceEntity(), "starforge-updateVendingStock", self.currentStock)

    widget.setVisible("emptyLabel", showEmptyLabel)
  end
end

function showWeapon(item)
  local playerMoney = player.currency("money")
  local enableButton = false

  if item then
    local cost = item.parameters.price
    enableButton = playerMoney >= cost and not item.parameters.locked
    widget.setText(self.totalCost, string.format("%s", cost))
  else
    widget.setText(self.totalCost, string.format("--"))
  end

  widget.setButtonEnabled("btnBuy", enableButton)
end

function itemSelected()
  local listItem = widget.getListSelected(self.itemList)
  self.selectedItem = listItem

  if listItem then
    local listItem = string.format("%s.%s", self.itemList, self.selectedItem)
    local itemData = widget.getData(listItem)
    showWeapon(itemData.item)
  end
end

function purchase()
  if self.selectedItem then
    local listItem = string.format("%s.%s", self.itemList, self.selectedItem)
    local selectedData = widget.getData(listItem)
    local selectedItem = selectedData.item

    if selectedItem then
      --If we successfully consumed enough currency, give the new item to the player
      local consumedCurrency = player.consumeCurrency("money", selectedItem.parameters.price)
      if consumedCurrency then
        player.giveItem(selectedItem)
        widget.setVisible(string.format("%s.unavailableoverlay", listItem), true)
        widget.setText(string.format("%s.priceLabel", listItem), "Sold!")
        widget.setText(self.totalCost, string.format("--"))
        widget.setButtonEnabled("btnBuy", false)
      end
    end
    self.currentStock[selectedData.index].parameters.locked = true
    world.sendEntityMessage(pane.sourceEntity(), "starforge-updateVendingStock", self.currentStock)
    populateItemList()
  end
end

function calculateTier(tier)
  local level = tier

  -- The higher the tier, the lower the chance of change
  local stability = math.min(tier * 0.1, 1) -- caps at 1.0
  local rand = math.random()

  if rand < 0.1 * (1 - stability) then
    level = level + 1 -- rare boost
  elseif rand < 0.20 * (1 - stability) then
    level = math.max(0, level - 2) -- significant drop
  elseif rand < 0.50 * (1 - stability) then
    level = math.max(0, level - 1) -- mild drop
  end

  return level
end

function refreshSeeds(seed)
  self.seeds = {}
  for i = 1, self.weaponInventorySize do
	local newSeed = ((seed + i) % 4294967295) + 1
    table.insert(self.seeds, newSeed)
  end
end

function toTime(seconds)
  local minutes = math.floor(seconds / 60)
  local seconds = seconds % 60

  return string.format("%02d:%02d", minutes, seconds)
end