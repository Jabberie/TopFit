local addonName, ns, _ = ...

-- GLOBALS: TopFit
-- GLOBALS: GetProfessions, GetProfessionInfo, UnitClass, ClearCursor, EquipCursorItem, EquipmentManagerClearIgnoredSlotsForSave, EquipmentManagerIgnoreSlotForSave, InCombatLockdown, UnitIsDeadOrGhost, GetContainerNumSlots, GetContainerItemLink, GetInventoryItemLink, PickupContainerItem, PickupInventoryItem
-- GLOBALS: tremove, tinsert, select, wipe, pairs, math, string, strsplit, tonumber

function ns:StartCalculations(setCode)
	-- generate table of set codes
	ns.workSetList = ns.workSetList or {}
	wipe(ns.workSetList)

	if setCode then
		tinsert(ns.workSetList, ns.GetSetByID(setCode, true))
	else
		for _, setCode, _ in pairs(ns.GetSetList()) do
			tinsert(ns.workSetList, ns.GetSetByID(setCode, true))
		end
	end

	ns:CalculateSets()
end

function ns:AbortCalculations()
	if ns.isBlocked and ns.runningCalculation then
		ns.runningCalculation:Abort()
		ns.isBlocked = false
		ns.ui.SetButtonState('idle')
		ns.runningCalculation = nil
	end
end

function ns:CalculateSets(silent)
	if not ns.isBlocked then
		local set = tremove(ns.workSetList)

		ns.setCode = set.setID -- globally save the current set that is being calculated
		-- TODO: remove and replace all uses of it - will have to remember the currently calculating set in a different way, e.g. the calculation saving a reference to the set object

		local calculation = ns.DefaultCalculation(set)
		calculation:SetOperationsPerFrame(500)

		ns:Debug("Calculating items for "..set:GetName())

		-- set as working to prevent any further calls from "interfering" --TODO: remove
		ns.isBlocked = true

		-- copy caps
		set.calculationData.ignoreCapsForCalculation = false
		set.calculationData.silentCalculation = silent

		-- do the actual work
		ns:updateItemsCache()

		calculation.OnUpdate = ns.UpdateUIWithCalculationProgress
		calculation.OnComplete = ns.CalculationHasCompleted

		-- save equippable items
		local itemListBySlot = ns:GetEquippableItems() --TODO: replace with Calculation:AddItem(item, slot) mechanic
		ns.ReduceItemList(calculation.set, itemListBySlot)

		for slotID, items in pairs(itemListBySlot) do
			for _, item in ipairs(items) do
				calculation:AddItem(item, slotID)
				calculation:SetItemCount(item.itemLink, ns.GetItemCount(item.itemLink))
			end
		end

		TopFit.progress = nil
		calculation:Start()
		ns.runningCalculation = calculation
		ns.ui.SetButtonState('busy')
	end
end

function ns.UpdateUIWithCalculationProgress(calculation) --TODO: don't interact directly with calculation internals
	-- update progress
	local set = calculation.set
	local progress = calculation:GetCurrentProgress()
	if (TopFit.progress == nil) or (TopFit.progress < progress) then
		TopFit.progress = progress
		ns.ui.SetProgress(progress)
	end

	-- update icons and statistics
	if calculation.bestCombination then
		-- TODO: since we no longer have a statistics panel, we have no place to display this info
		-- SetCurrentCombination(calculation.bestCombination)
	end

	ns:Debug("Current combination count: "..calculation.combinationCount)
end

function ns.CalculationHasCompleted(calculation) --TODO: don't interact directly with calculation internals
	local set = calculation.set

	-- find best combination that satisfies ALL caps
	if (calculation.bestCombination) then
		--ns:Print("Total Score: " .. math.ceil(calculation.bestCombination.totalScore))
		-- TODO: find a way to create decent output like "Increased set score by 5%"
		-- caps are reached, save and equip best combination
		ns.itemRecommendations = {}
		for slotID, itemTable in pairs(calculation.bestCombination.items) do
			ns.itemRecommendations[slotID] = itemTable.itemLink
		end

		ns.EquipRecommendedItems(set)
		ns.runningCalculation = nil
		ns.ui.SetButtonState()
	else
		-- caps could not all be reached, calculate without caps instead
		if not set.calculationData.silentCalculation then
			ns:Print(ns.locale.ErrorCapNotReached)
		end

		-- start over without hard caps
		-- TODO: copy the current set, but remove all caps, and use that for calculating again
		set:ClearAllHardCaps()
		set.calculationData.ignoreCapsForCalculation = true
		calculation:Start()
	end
end

function TopFit.EquipRecommendedItems(set)
	-- skip equipping if virtual items were included
	if set:GetUseVirtualItems() then
		local virtualItems = set:GetVirtualItems()
		if #virtualItems > 0 then
			TopFit:Print(TopFit.locale.NoticeVirtualItemsUsed)

			-- reenable options and quit
			TopFit.isBlocked = false
			ns.ui.SetButtonState('idle')

			-- reset relevant score field
			set.calculationData.ignoreCapsForCalculation = nil

			-- initiate next calculation if necessary
			if (#TopFit.workSetList > 0) then
				TopFit:CalculateSets()
			end
			return
		end
	end

	-- equip them
	TopFit.updateEquipmentCounter = 10000
	TopFit.equipRetries = 0
	TopFit.updateFrame.currentlyEquippingSet = set
	TopFit.updateFrame:SetScript("OnUpdate", TopFit.onUpdateForEquipment)
end

function TopFit.onUpdateForEquipment(frame, elapsed)
	local set = frame.currentlyEquippingSet --TODO: maybe find a better way than using this variable

	-- don't try equipping in combat or while dead
	if InCombatLockdown() or UnitIsDeadOrGhost("player") then
		return
	end

	-- see if all items already fit
	local slotItemLink
	local allDone = true
	for slotID, itemLink in pairs(TopFit.itemRecommendations) do
		if (set:GetItemScore(itemLink) > 0) then --TODO: check if it makes sense to check for positive score here - there might be forced items and whatnot
			slotItemLink = GetInventoryItemLink("player", slotID)
			if (slotItemLink ~= itemLink) then
				allDone = false
			end
		end
	end

	TopFit.updateEquipmentCounter = TopFit.updateEquipmentCounter + elapsed

	-- try equipping the items every 100 frames (some weird ring positions might stop us from correctly equipping items on the first try, for example)
	if (TopFit.updateEquipmentCounter > 1) then
		for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
			local recItemLink = TopFit.itemRecommendations[slotID]
			-- Only do something if the suggested item is not yet equipped.
			if recItemLink and recItemLink ~= GetInventoryItemLink("player", slotID) then
				local locations = TopFit.GetItemLocations(recItemLink)

				-- Try to equip the item.
				ClearCursor()
				local hasItem = false
				for _, location in ipairs(locations) do
					hasItem = TopFit.PickupItemFromLocation(location)
					if hasItem then break end
				end
				if hasItem then
					EquipCursorItem(slotID)
				else
					TopFit:Print(string.format(TopFit.locale.ErrorItemNotFound, recItemLink))
					TopFit.itemRecommendations[slotID] = nil
				end
			end
		end
		TopFit.updateEquipmentCounter = 0
		TopFit.equipRetries = TopFit.equipRetries + 1
	end

	-- if all items have been equipped, save equipment set and unregister script
	-- also abort if it takes to long, just save the items that _have_ been equipped
	if ((allDone) or (TopFit.equipRetries > 5)) then
		frame.currentlyEquippingSet = nil

		if (not allDone) then
			TopFit:Print(TopFit.locale.NoticeEquipFailure)

			for slotID, recItemLink in pairs(TopFit.itemRecommendations) do
				slotItemLink = GetInventoryItemLink("player", slotID)
				if (slotItemLink ~= recItemLink) then
					TopFit:Print(string.format(TopFit.locale.ErrorEquipFailure, recItemLink, slotID, TopFit.slotNames[slotID]))
					TopFit.itemRecommendations[slotID] = nil
				end
			end
		end

		TopFit:Debug("All Done!")
		TopFit.updateFrame:SetScript("OnUpdate", nil)
		ns.ui.SetButtonState('idle')

		C_EquipmentSet.ClearIgnoredSlotsForSave()
		for _, slotID in pairs(TopFit.slots) do
			if (not TopFit.itemRecommendations[slotID]) then
				TopFit:Debug("Ignoring slot "..slotID)
				C_EquipmentSet.IgnoreSlotForSave(slotID)
			end
		end

		-- save equipment set
		ns:CreateEquipmentManagerSet(set)

		-- we are done with this set
		TopFit.isBlocked = false

		-- reset relevant score field
		set.calculationData.ignoreCapsForCalculation = nil

		-- initiate next calculation if necessary
		if (#TopFit.workSetList > 0) then
			TopFit:CalculateSets()
		end
	end
end

-- remove all other items in slots that have forced items in them
function ns.RemoveNonForcedItemsFromItemList(set, itemList)
	local setForcedItems = set:GetForcedItems()
	for slotID, _ in pairs(ns.slotNames) do
		local forcedItems = setForcedItems[slotID]
		if itemList[slotID] and forcedItems and #forcedItems > 0 then
			for i = #(itemList[slotID]), 1, -1 do
				local itemTable = ns:GetCachedItem(itemList[slotID][i].itemLink)
				if not itemTable then
					ns:Debug('Reduce: No item info', itemList[slotID][i].itemLink)
					tremove(itemList[slotID], i)
				else
					local found = false
					for _, forceID in pairs(forcedItems) do
						if forceID == itemTable.itemID then
							found = true
							break
						end
					end

					if not found then
						ns:Debug('Reduce: Not a forced item in a forced slot', itemList[slotID][i].itemLink)
						tremove(itemList[slotID], i)
					end
				end
			end
		end

		if (slotID == 17 and forcedItems and #forcedItems > 0) then -- offhand
			--TODO: check if forced item is a weapon and remove all weapons from mainhand if player cannot dualwield
			-- always remove all 2H-weapons from mainhand
			for i = #(itemList[16]), 1, -1 do
				if (not set:IsOnehandedWeapon(itemList[16][i].itemLink)) then
					ns:Debug('Reduce: Two-handed weapon when offhand is forced', itemList[16][i].itemLink)
					tremove(itemList[16], i)
				end
			end
		end
	end
end

-- if enabled, remove armor that is not part of armor specialization
function ns.RemoveWrongArmorTypesFromItemList(set, itemList)
	if set:GetForceArmorType() and ns.characterLevel >= 50 then
		local playerClass = select(2, UnitClass("player"))
		local setForcedItems = set:GetForcedItems()
		for slotID, _ in pairs(ns.armoredSlots) do
			if itemList[slotID] and (not setForcedItems[slotID] or #(setForcedItems[slotID]) == 0) then
				for i = #(itemList[slotID]), 1, -1 do
					local itemTable = ns:GetCachedItem(itemList[slotID][i].itemLink)
					if playerClass == "DRUID" or playerClass == "ROGUE" or playerClass == "MONK" then
						if not itemTable or not itemTable.totalBonus["TOPFIT_ARMORTYPE_LEATHER"] then
							ns:Debug('Reduce: Wrong armor type', itemList[slotID][i].itemLink)
							tremove(itemList[slotID], i)
						end
					elseif playerClass == "HUNTER" or playerClass == "SHAMAN" then
						if not itemTable or not itemTable.totalBonus["TOPFIT_ARMORTYPE_MAIL"] then
							ns:Debug('Reduce: Wrong armor type', itemList[slotID][i].itemLink)
							tremove(itemList[slotID], i)
						end
					elseif playerClass == "WARRIOR" or playerClass == "DEATHKNIGHT" or playerClass == "PALADIN" then
						if not itemTable or not itemTable.totalBonus["TOPFIT_ARMORTYPE_PLATE"] then
							ns:Debug('Reduce: Wrong armor type', itemList[slotID][i].itemLink)
							tremove(itemList[slotID], i)
						end
					end
				end
			end
		end
	end
end

--remove items that are marked as bind on equip
function ns.RemoveBindOnEquipItemsFromItemList(set, itemList)
	for slotID, itemList in pairs(itemList) do
		if #itemList > 0 then
			for i = #itemList, 1, -1 do
				if itemList[i].isBoE then
					ns:Debug('Reduce: Binds on equip', itemList[i].itemLink)
					tremove(itemList, i)
				end
			end
		end
	end
end

local professionSkills = {}
local function RemoveUnusableSkillItems(set, subList)
	local professions = {GetProfessions()}

	wipe(professionSkills)
	for _, prof in pairs(professions) do
		local _, _, skill, _, _, _, profession = GetProfessionInfo(prof)
		professionSkills[profession] = skill
	end

	for i = #subList, 1, -1 do
		local itemStats
		if subList[i].stats then
			itemStats = subList[i].stats
		elseif subList[i].itemLink then
			local itemTable = ns:GetCachedItem(subList[i].itemLink)
			itemStats = itemTable and itemTable.totalBonus
		end
		if not itemStats then
			ns:Debug('Reduce: No item info', subList[i].itemLink)
			tremove(subList, i)
		else
			for statCode, statValue in pairs(itemStats) do
				local profession = tonumber(string.match(statCode, "^SKILL: (.+)") or "")
				if profession and (not professionSkills[profession] or professionSkills[profession] < statValue) then
					ns:Debug('Reduce: Profession requirements not met', subList[i].itemLink)
					tremove(subList, i)
				end
			end
		end
	end
end

--- Remove items that are unusable because their item level requirement is too high
local function RemoveUnusableLevelItems(set, subList)
	for i = #subList, 1, -1 do
		if subList[i].itemLink then
			local itemTable = ns:GetCachedItem(subList[i].itemLink)
			if itemTable.itemMinLevel > ns.characterLevel then
				tremove(subList, i)
			end
		end
	end
end

function ns.RemoveUnusableItemsFromItemList(set, subList)
	RemoveUnusableSkillItems(set, subList)
	RemoveUnusableLevelItems(set, subList)
end

function ns.RemoveItemsBelowThresholdFromItemList(set, subList)
	if #subList >= 1 then
		for i = #subList, 1, -1 do
			local score = set:GetItemScore(subList[i].itemLink)
			if (score <= 0) then
				-- check caps
				local hasCap = false

				local itemStats = nil
				if subList[i].stats then
					itemStats = subList[i].stats
				elseif subList[i].itemLink then
					local itemTable = ns:GetCachedItem(subList[i].itemLink)
					itemStats = itemTable and itemTable.totalBonus
				end

				for statCode, _ in pairs(set:GetHardCaps()) do
					if itemStats and (itemStats[statCode] or -1) > 0 then
						hasCap = true
						break
					end
				end

				if not hasCap then
					ns:Debug('Reduce: Non-positive score', score, subList[i].itemLink)
					tremove(subList, i)
				end
			end
		end
	end
end

function ns.RemoveLowScoreItemsFromItemList(set, subList, numBetterItemsNeeded, problematicUniqueness)
	if #subList > 1 then
		for i = #subList, 1, -1 do
			local itemStats, itemTable
			if subList[i].stats then
				itemStats = subList[i].stats
			elseif subList[i].itemLink then
				itemTable = ns:GetCachedItem(subList[i].itemLink)
				itemStats = itemTable and itemTable.totalBonus
			end
			if not itemTable then
				ns:Debug('Reduce: No item info', subList[i].itemLink)
				tremove(subList, i)
			else
				-- try to see if an item exists which is definitely better
				local betterItemExists = 0
				for j = 1, #subList do
					if i ~= j then
						local compareStats, compareTable
						if subList[j].stats then
							compareStats = subList[i].stats
						elseif subList[j].itemLink then
							compareTable = ns:GetCachedItem(subList[j].itemLink)
							compareStats = compareTable and compareTable.totalBonus
						end
						if compareTable and
							(set:GetItemScore(itemTable.itemLink) <= set:GetItemScore(compareTable.itemLink)) and
							(itemTable.itemEquipLoc == compareTable.itemEquipLoc) then -- especially important for weapons, we do not want to compare 2h and 1h weapons

							-- score is greater, see if caps are also better
							local allStats = true
							for statCode, _ in pairs(set:GetHardCaps()) do
								if (itemTable.totalBonus[statCode] or 0) > (compareTable.totalBonus[statCode] or 0) then
									allStats = false
									break
								end
							end

							if allStats then
								-- items with a problematic uniqueness are special and don't count as a better item
								for stat, _ in pairs(compareTable.totalBonus) do
									if (string.sub(stat, 1, 8) == "UNIQUE: ") and problematicUniqueness and problematicUniqueness == "all" or problematicUniqueness[stat] then
										allStats = false
									end
								end

								if allStats then
									betterItemExists = betterItemExists + 1
									if (betterItemExists >= numBetterItemsNeeded) then
										break
									end
								end
							end
						end
					end
				end

				if betterItemExists >= numBetterItemsNeeded then
					ns:Debug('Reduce: Better items found', betterItemExists, subList[i].itemLink)
					tremove(subList, i)
				end
			end
		end
	end
end

function ns.ReduceGemList(set, gemList)
	for _, subList in pairs(gemList) do
		ns.RemoveUnusableItemsFromItemList(set, subList)
		ns.RemoveItemsBelowThresholdFromItemList(set, subList)
		ns.RemoveLowScoreItemsFromItemList(set, subList, 1, "all")
	end
end

function ns.ReduceItemList(set, itemList)
	ns.RemoveNonForcedItemsFromItemList(set, itemList)
	ns.RemoveWrongArmorTypesFromItemList(set, itemList)
	ns.RemoveBindOnEquipItemsFromItemList(set, itemList)
	-- @todo [optional] remove inapropriate spec/azerite items.

	-- remove all items with score <= 0 that are neither forced nor contribute to caps
	for slotID, subList in pairs(itemList) do
		ns.RemoveUnusableItemsFromItemList(set, subList)

		if #(set:GetForcedItems(slotID)) == 0 then
			ns.RemoveItemsBelowThresholdFromItemList(set, subList)
		end
	end

	-- preprocess unique items - so we are able to remove items when uniqueness doesn't matter in the next step
	-- step 1: sum up the number of unique items for each uniqueness family
	local preprocessUniqueness = {}
	for slotID, slotItemList in pairs(itemList) do
		if #slotItemList > 1 then
			for i = #slotItemList, 1, -1 do
				local itemTable = TopFit:GetCachedItem(slotItemList[i].itemLink)
				if itemTable then
					for stat, value in pairs(itemTable.totalBonus) do
						if (string.sub(stat, 1, 8) == "UNIQUE: ") then
							preprocessUniqueness[stat] = (preprocessUniqueness[stat] or 0) + value
						end
					end
				end
			end
		end
	end

	-- step 2: remember all uniqueness families where uniqueness could actually be violated
	local problematicUniqueness = {}
	for stat, value in pairs(preprocessUniqueness) do
		local _, maxCount = strsplit("*", stat)
		maxCount = tonumber(maxCount)
		if value > maxCount then
			problematicUniqueness[stat] = true
		end
	end

	-- reduce item list: remove items with < cap and < score
	for slotID, subList in pairs(itemList) do
		local numBetterItemsNeeded = 1

		-- For items that can be used in 2 slots, we also need at least 2 better items to declare an item useless
		if (slotID == 17) -- offhand
			or (slotID == 12) -- ring 2
			or (slotID == 14) -- trinket 2
			then

			numBetterItemsNeeded = 2
		end

		ns.RemoveLowScoreItemsFromItemList(set, subList, numBetterItemsNeeded, problematicUniqueness)
	end
end
