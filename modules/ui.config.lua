local addonName, ns, _ = ...
ns.ui = ns.ui or {}
local ui = ns.ui

-- GLOBALS: NORMAL_FONT_COLOR, _G, UIParent, GameTooltip, assert, hooksecurefunc, unpack, select
-- GLOBALS: PlaySound, CreateFrame, ShowUIPanel, HideUIPanel, SetPortraitToTexture, GetTexCoordsForRole, ButtonFrameTemplate_HideAttic

function ui.CreateConfigPanel(isFull)
	-- default: including header
	local panel = CreateFrame("Frame", nil, _G["TopFitConfigFrameSpecialization"])
		  panel.displayHeader = not isFull
		  panel:Hide()
	local button = ui.GetSidebarButton()
		  button.panel = panel
		  panel.button = button

	return button, panel
end

local function SetHeaderData(scrollChild, panel)
	if panel.icon then
		SetPortraitToTexture(scrollChild.specIcon, panel.icon or "")
		scrollChild.specIcon:Show()
	else
		scrollChild.specIcon:Hide()
	end
	scrollChild.specName:SetText( panel.title or "" )
	scrollChild.description:SetText( panel.description or "" )
	scrollChild.roleName:SetText( panel.subTitle or "" )
	scrollChild.roleIcon:SetTexture( panel.subIcon or "" )
	if panel.subIconCoords and #(panel.subIconCoords) >= 4 then
		scrollChild.roleIcon:SetTexCoord( unpack(panel.subIconCoords) )
	end
end

local function DisplayScrollFramePanel(scrollFrame, panel)
	assert(scrollFrame and panel, "Missing arguments. Usage: DisplayScrollFramePanel(scrollFrame, panel)")
	local buttonID = 1
	local button = _G[panel:GetParent():GetName().."SpecButton"..buttonID]
	while button do
		ui.SetSidebarButtonState(button, button:GetID() == panel.button:GetID())
		button.selected = button:GetID() == panel.button:GetID()

		buttonID = buttonID + 1
		button = _G[panel:GetParent():GetName().."SpecButton"..buttonID]
	end

	if panel.displayHeader then
		scrollFrame:GetScrollChild():Hide()
		scrollFrame:SetScrollChild( _G[scrollFrame:GetName().."ScrollChild"] )
		local scrollChild = scrollFrame:GetScrollChild()
		scrollChild.abilityButton1:Hide()
		scrollChild:Show()

		SetHeaderData(scrollChild, panel)

		if scrollChild.panel then
			scrollChild.panel:Hide()
		end
		scrollChild.panel = panel
		scrollChild.panel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, -185)
		scrollChild.panel:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -10, -185)
		scrollChild.panel:Show()
	else
		scrollFrame:GetScrollChild():Hide()
		scrollFrame:SetScrollChild(panel)
		scrollFrame:GetScrollChild():Show()
	end
end
local function ButtonOnClick(self)
	GameTooltip:Hide()
	PlaySound("igMainMenuOptionCheckBoxOn")

	local scrollFrame = self:GetParent().spellsScroll
	scrollFrame.ScrollBar:SetValue(0)

	DisplayScrollFramePanel(scrollFrame, self.panel)

--[[ -- example code
	scrollChild.specName:SetText("Panel for "..self.specName:GetText())
	SetPortraitToTexture(scrollChild.specIcon, "Interface\\Icons\\Achievement_BG_trueAVshutout")
	scrollChild.roleIcon:SetTexCoord(GetTexCoordsForRole("DAMAGER"))
	scrollChild.roleName:SetText("Settings for important things.")
	scrollChild.description:SetText("This is a panel to configure your own settings. It is very important and you should always check here first! Don't worry if it's a whole lot of text, it really isn't.")

	local text = _G[scrollChild:GetName() .. "CustomText"]
	if not text then
		text = scrollChild:CreateFontString("$parentCustomText", "BACKGROUND", "GameFontNormal")
		text:SetPoint("TOPLEFT", 20, -185)
		text:SetJustifyH("LEFT")
		text:SetJustifyV("TOP")
		text:SetWordWrap(true)
	end

	text:SetText("Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\nLorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\nLorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n")

	text:SetWidth( scrollChild:GetWidth() - 20 - 10 )
--]]
	-- /spew TopFitConfigFrameSpecialization.spellsScroll.child
end
local function ButtonOnEnter(self)
	-- if not self.selected then
	if self.tooltip and self.tooltip ~= "" then
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(self.tooltip, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		GameTooltip:Show()
	end
end
local function ButtonOnLeave(self)
	GameTooltip:Hide()
end

function ui.GetSidebarButton(index)
	local frame = _G["TopFitConfigFrameSpecialization"]
	assert(frame, "TopFitConfigFrame has not been initialized properly.")

	-- allow calling this func w/o knowing the next id
	if not index then
		index = 1
		while _G[frame:GetName() .. "SpecButton" .. index] and not frame["specButton"..index] do
			index = index + 1
		end
	end

	local button = _G[frame:GetName() .. "SpecButton" .. index]
	if not button or frame["specButton"..index] then
		if not button then
			button = CreateFrame("Button", "$parentSpecButton"..index, frame, "PlayerSpecButtonTemplate")
			button:SetID(index)

		end

		button:SetScript("OnClick", ButtonOnClick)
		button:SetScript("OnEnter", ButtonOnEnter)
		button:SetScript("OnLeave", ButtonOnLeave)

		button:ClearAllPoints()
		if index == 1 then
			button:SetPoint("TOPLEFT", 6, -65) -- -56
		else
			button:SetPoint("TOP", "$parentSpecButton"..(index-1), "BOTTOM", 0, -10)
		end

		button.roleIcon:Hide()
		button.roleName:Hide()
		button.ring:SetTexture("Interface\\TalentFrame\\spec-filagree") 			-- Interface\\TalentFrame\\talent-main
		button.ring:SetTexCoord(0.00390625, 0.27734375, 0.48437500, 0.75781250) 	-- 0.50000000, 0.91796875, 0.00195313, 0.21093750
		button.specIcon:SetSize(100-14, 100-14) 									-- 100/66 (filagree is 70/56)

		ui.SetSidebarButtonHeight(button, 40)
		if frame["specButton"..index] then
			frame["specButton"..index] = nil
		end
	end
	button:Show()

	return button
end
function ui.SetSidebarButtonState(button, active)
	if active then
		button.selected = true
		button.selectedTex:Show()
		button.learnedTex:Show()
	else
		button.selected = nil
		button.selectedTex:Hide()
		button.learnedTex:Hide()
	end
end
function ui.SetSidebarButtonHeight(button, height)
	button:SetHeight(height) 							-- 60
	button.bg:SetHeight(height+20) 						-- 80
	button.selectedTex:SetHeight(height+20) 			-- 80
	button.learnedTex:SetHeight(2*height+8) 			-- 128
	button:GetHighlightTexture():SetHeight(height+20) 	-- 80

	local ringSize = 80/60 * height 					-- 100
	button.specIcon:SetSize(ringSize*4/5, ringSize*4/5) -- 2/3
	button.ring:SetSize(ringSize, ringSize)
	button.ring:ClearAllPoints()
	button.ring:SetPoint("LEFT", "$parent", "LEFT", 4, 0)
end
function ui.SetSidebarButtonData(button, name, tooltip, texture, role)
	if texture then
		SetPortraitToTexture(button.specIcon, texture)
		button.ring:Show()
	else
		button.ring:Hide()
	end
	button.specName:SetText(name)
	button.tooltip = tooltip
	if role then
		button.roleIcon:SetTexCoord(GetTexCoordsForRole(role))
		button.roleName:SetText(_G[role])
		button.roleIcon:Show()
		button.roleName:Show()

		button.specName:ClearAllPoints()
		button.specName:SetPoint("BOTTOMLEFT", "$parentRing", "RIGHT", 0, 0)
	else
		button.roleIcon:Hide()
		button.roleName:Hide()

		button.specName:ClearAllPoints()
		button.specName:SetPoint("LEFT", "$parentRing", "RIGHT", 0, 0)
	end
end

function ui.SetHeaderTitle(panel, title)
	panel.title = title or ""
	if panel:IsShown() then
		panel:GetParent().spellsScroll:GetScrollChild().specName:SetText(title or "")
	end
end
function ui.SetHeaderIcon(panel, texture)
	panel.icon = texture
	if panel:IsShown() then
		local scrollChild = panel:GetParent().spellsScroll:GetScrollChild()
		if texture and texture ~= "" then
			SetPortraitToTexture(scrollChild.specIcon, texture)
			scrollChild.specIcon:Show()
		else
			scrollChild.specIcon:Hide()
		end
	end
end
function ui.SetHeaderSubTitle(panel, subTitle)
	panel.subTitle = subTitle or ""
	if panel:IsShown() then
		panel:GetParent().spellsScroll:GetScrollChild().roleName:SetText(subTitle)
	end
end
function ui.SetHeaderSubTitleIcon(panel, texture, ...)
	panel.subIcon = texture
	if select('#', ...) >= 4 then
		panel.subIconCoords = { ... }
	end
	if panel:IsShown() then
		local scrollChild = panel:GetParent().spellsScroll:GetScrollChild()
		scrollChild.roleIcon:SetTexture(texture)
		if select('#', ...) >= 4 then
			scrollChild.roleIcon:SetTexCoord( ... )
		end

	end
end
function ui.SetHeaderDescription(panel, text)
	panel.description = text or ""
	if panel:IsShown() then
		panel:GetParent().spellsScroll:GetScrollChild().description:SetText( text or "" )
	end
end
function ui.SetPanelDisplayHeader(panel, displayHeader)
	local oldState = panel.displayHeader
	panel.displayHeader = displayHeader
	if panel:IsShown() and oldState ~= displayHeader then
		ui.ShowPanel(panel)
	end
end

function ui.ShowPanel(panel)
	DisplayScrollFramePanel(_G["TopFitConfigFrameSpecializationSpellScrollFrame"], panel)
end

function ui.ToggleTopFitConfigFrame()
	local frame = _G["TopFitConfigFrame"]
	if not frame then
		LoadAddOn("Blizzard_TalentUI") -- won't double init anyways

		frame = CreateFrame("Frame", "TopFitConfigFrame", UIParent, "ButtonFrameTemplate")
		frame:EnableMouse()
		frame:SetSize(646, 468)

		frame:SetAttribute("UIPanelLayout-defined", true)
		frame:SetAttribute("UIPanelLayout-enabled", true)
		frame:SetAttribute("UIPanelLayout-whileDead", true)
		frame:SetAttribute("UIPanelLayout-area", "left")
		frame:SetAttribute("UIPanelLayout-pushable", 5) 	-- when competing for space, lower numbers get closed first
		frame:SetAttribute("UIPanelLayout-width", 666) 		-- width + 20
		frame:SetAttribute("UIPanelLayout-height", 488) 	-- height + 20

		-- when changing panel size, also adjust:
		-- 		frame:SetSize(550, 468)
		-- 		TestFrameInsetSpecialization.bg:SetWidth(646-217)
		-- 		TestFrameInsetSpecializationSpellScrollFrame:SetPoint("BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", 0, 0)
		-- 		TestFrameInsetSpecializationSpellScrollFrameScrollChild:SetAllPoints()

		ButtonFrameTemplate_HideAttic(frame)
		SetPortraitToTexture(frame:GetName().."Portrait", "Interface\\Icons\\Achievement_BG_trueAVshutout")
		frame.TitleText:SetText("TopFit")

		local frameContent = CreateFrame("Frame", frame:GetName().."Specialization", frame.Inset, "SpecializationFrameTemplate")
		frameContent:ClearAllPoints()
		frameContent:SetAllPoints()
		frameContent:SetFrameLevel(0) -- put below parent
		frameContent:SetFrameLevel(1) -- and then raise again!

		frameContent.MainHelpButton:Hide()
		frameContent.learnButton:Hide()

		-- reanchor textures so they don't scroll later on
		local scrollChild = _G[frameContent:GetName().."SpellScrollFrameScrollChild"]
		scrollChild:SetPoint("BOTTOMRIGHT") -- for smooth resizing
		scrollChild.scrollwork_topleft:SetParent(frameContent)
		scrollChild.scrollwork_topleft:ClearAllPoints()
		scrollChild.scrollwork_topleft:SetPoint("TOPLEFT", 217, 0)
		scrollChild.scrollwork_topright:SetParent(frameContent)
		scrollChild.scrollwork_topright:ClearAllPoints()
		scrollChild.scrollwork_topright:SetPoint("TOPRIGHT", 0, 0)
		scrollChild.scrollwork_bottomleft:SetParent(frameContent)
		scrollChild.scrollwork_bottomleft:ClearAllPoints()
		scrollChild.scrollwork_bottomleft:SetPoint("BOTTOMLEFT", 217, 8)
		scrollChild.scrollwork_bottomright:SetParent(frameContent)
		scrollChild.scrollwork_bottomright:ClearAllPoints()
		scrollChild.scrollwork_bottomright:SetPoint("BOTTOMRIGHT", 0, 8)
		scrollChild.gradient:SetParent(frameContent)
		scrollChild.gradient:SetPoint("TOPLEFT", 217-9, 0)

		local index = 1
		while frameContent["specButton"..index] do
			frameContent["specButton"..index]:Hide()
			index = index + 1
		end

		hooksecurefunc(scrollChild:GetParent(), "SetVerticalScroll", function(self, scroll)
			local hasScrollBar = self:GetVerticalScrollRange() > 0
			self:SetPoint("BOTTOMRIGHT", hasScrollBar and -24 or 0, 4)
		end)

		-- example code
		for i = 1, 2 do
			local btn, panel = ui.CreateConfigPanel()
			ui.SetSidebarButtonData(btn, "SpecButton"..i, "TestButton"..i, i%2==0 and "Interface\\Icons\\Achievement_BG_trueAVshutout" or nil)
			-- ui.SetSidebarButtonHeight(btn, 40)
			-- ui.SetSidebarButtonState(btn, i==1)
			panel.title = "Lorem Ipsum"
			panel.subTitle = "Dolor sit amet"
			panel.description = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation."
			panel.icon = "Interface\\Icons\\Achievement_BG_trueAVshutout"
		end
		frame:Hide()

		-- initialize plugin config panels
		for _, plugin in pairs(ns.currentPlugins) do
			plugin:CreateConfigPanel()
		end
	end

	if frame:IsShown() then
		HideUIPanel(frame)
	else
		ShowUIPanel(frame)
	end
end

function ui.IsConfigFrameInitialized()
	return _G["TopFitConfigFrame"] and true or false
end