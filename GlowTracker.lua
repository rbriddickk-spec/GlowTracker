GlowSpellsDB = GlowSpellsDB or {}
GlowSpellsDB   = GlowSpellsDB   or {}
GlowTrackerDB  = GlowTrackerDB  or {}
GlowTrackerDB.minimap = GlowTrackerDB.minimap or {
    angle = 45,   -- degrees around minimap
    free  = false,
    x     = 0,
    y     = 0,
}
GlowTrackerDB.window = GlowTrackerDB.window or {
    x     = 0,
    y     = 0,
    shown = false,
}


local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
f:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
f:RegisterEvent("SPELL_UPDATE_USABLE")

local function GetSpecKey()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    if not spec then return class, "NOSPEC" end
    local specName = select(2, GetSpecializationInfo(spec))
    return class, specName:upper()
end

local function AddGlow(spellID, glowType, trigger)
    local class, spec = GetSpecKey()
    GlowSpellsDB[class] = GlowSpellsDB[class] or {}
    GlowSpellsDB[class][spec] = GlowSpellsDB[class][spec] or {}

    GlowSpellsDB[class][spec][spellID] = GlowSpellsDB[class][spec][spellID] or {
        spell = spellID,
        types = {},
        triggers = {},
    }

    GlowSpellsDB[class][spec][spellID].types[glowType] = true
    if trigger then
        GlowSpellsDB[class][spec][spellID].triggers[trigger] = true
    end
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellID = ...
        AddGlow(spellID, "SAO", "Overlay")
    end

    if event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE" then
        for slot = 1, 120 do
            local actionType, id = GetActionInfo(slot)
            if actionType == "spell" and id then
                if IsSpellOverlayed(id) then
                    AddGlow(id, "USABLE", "IsSpellOverlayed")
                end
            end
        end
    end
end)
local exportFrame, exportEditBox, classDropDown, specDropDown

local function GlowTracker_GetClassSpecList()
    local classes = {}
    for class, specs in pairs(GlowSpellsDB) do
        local specList = {}
        for spec in pairs(specs) do
            table.insert(specList, spec)
        end
        table.sort(specList)
        table.insert(classes, { class = class, specs = specList })
    end
    table.sort(classes, function(a, b) return a.class < b.class end)
    return classes
end

local function GlowTracker_BuildExportText(class, spec)
    if not GlowSpellsDB[class] or not GlowSpellsDB[class][spec] then
        return "-- No data for " .. class .. " " .. spec
    end

    local lines = {}
    table.insert(lines, class .. " = {")
    table.insert(lines, "  " .. spec .. " = {")
    for spellID, info in pairs(GlowSpellsDB[class][spec]) do
        local name = GetSpellInfo(spellID) or "Unknown"
        table.insert(lines, string.format(
            "    [%d] = { spell = %d, -- %s",
            spellID, spellID, name
        ))
        table.insert(lines, "      types = {")
        local typeKeys = {}
        for t in pairs(info.types) do table.insert(typeKeys, t) end
        table.sort(typeKeys)
        for _, t in ipairs(typeKeys) do
            table.insert(lines, "        " .. t .. " = true,")
        end
        table.insert(lines, "      },")
        table.insert(lines, "      triggers = {")
        local trigKeys = {}
        for trig in pairs(info.triggers) do table.insert(trigKeys, trig) end
        table.sort(trigKeys)
        for _, trig in ipairs(trigKeys) do
            table.insert(lines, string.format("        [\"%s\"] = true,", trig))
        end
        table.insert(lines, "      },")
        table.insert(lines, "    },")
    end
    table.insert(lines, "  },")
    table.insert(lines, "},")
    return table.concat(lines, "\n")
end

local currentClass, currentSpec

local function GlowTracker_UpdateExportText()
    if not exportEditBox or not currentClass or not currentSpec then return end

    exportEditBox:SetText(GlowTracker_BuildExportText(currentClass, currentSpec))
    GlowTracker_RefreshEditBoxSize()
    exportEditBox:HighlightText(0, 0)
    exportEditBox:SetCursorPosition(0)
end


local function GlowTracker_InitClassDropDown()
    if not classDropDown then return end

    local classes = GlowTracker_GetClassSpecList()

    UIDropDownMenu_Initialize(classDropDown, function(self, level)
        for _, c in ipairs(classes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = c.class
            info.func = function()
                currentClass = c.class
                UIDropDownMenu_SetText(classDropDown, c.class)

                -- Reset spec when class changes
                currentSpec = nil
                GlowTracker_InitSpecDropDown()
                GlowTracker_UpdateExportText()
            end
            info.checked = (c.class == currentClass)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Default to first class if none selected
    if not currentClass and classes[1] then
        currentClass = classes[1].class
    end

    UIDropDownMenu_SetText(classDropDown, currentClass or "Class")
end

local function GlowTracker_InitSpecDropDown()
    if not specDropDown then return end

    local classes = GlowTracker_GetClassSpecList()
    local specsForClass = {}

    for _, c in ipairs(classes) do
        if c.class == currentClass then
            specsForClass = c.specs
            break
        end
    end

    UIDropDownMenu_Initialize(specDropDown, function(self, level)
        for _, spec in ipairs(specsForClass) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = spec
            info.func = function()
                currentSpec = spec
                UIDropDownMenu_SetText(specDropDown, spec)
                GlowTracker_UpdateExportText()
            end
            info.checked = (spec == currentSpec)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Default to first spec if none selected
    if not currentSpec and specsForClass[1] then
        currentSpec = specsForClass[1]
    end

    UIDropDownMenu_SetText(specDropDown, currentSpec or "Spec")
end
local function GlowTracker_RefreshEditBoxSize()
    if not exportEditBox then return end
    exportEditBox:SetWidth(540) -- same width you used originally
    exportEditBox:SetHeight(exportEditBox:GetStringHeight() + 20)
end


local function GlowTracker_CreateExportWindow()
    if exportFrame then return end

    exportFrame = CreateFrame("Frame", "GlowTrackerExportFrame", UIParent)
    exportFrame:SetSize(600, 400)
    exportFrame:SetPoint("CENTER")
    exportFrame:SetMovable(true)
    exportFrame:EnableMouse(true)
    exportFrame:RegisterForDrag("LeftButton")
    exportFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    exportFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetLeft(), self:GetTop()
        GlowTrackerDB.window.x = x
        GlowTrackerDB.window.y = y
    end)
    exportFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    exportFrame:SetClampedToScreen(true)

    exportFrame:Hide()
    table.insert(UISpecialFrames, "GlowTrackerExportFrame")

    local title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetText("GlowTracker Export")

    local close = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    classDropDown = CreateFrame("Frame", "GlowTrackerClassDropDown", exportFrame, "UIDropDownMenuTemplate")
    classDropDown:SetPoint("TOPLEFT", 15, -35)

    specDropDown = CreateFrame("Frame", "GlowTrackerSpecDropDown", exportFrame, "UIDropDownMenuTemplate")
    specDropDown:SetPoint("TOPLEFT", 200, -35)

-- Select All button (left of the hint)
local selectAllBtn = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
selectAllBtn:SetSize(80, 22)
selectAllBtn:SetPoint("LEFT", specDropDown, "RIGHT", 10, 0)
selectAllBtn:SetText("Select All")
selectAllBtn:SetScript("OnClick", function()
    if exportEditBox then
        exportEditBox:HighlightText()
        exportEditBox:SetFocus()
        copyHint:SetAlpha(1) -- brighten text
    end
end)

-- Ctrl+C indicator text (to the right of the button)
local copyHint = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
copyHint:SetPoint("LEFT", selectAllBtn, "RIGHT", 10, 0)
copyHint:SetText("Press Ctrl+C")
copyHint:SetAlpha(0.3)


	exportEditBox:SetScript("OnKeyDown", function(self, key)
		if IsControlKeyDown() and (key == "C" or key == "A") then
			self:SetPropagateKeyboardInput(true)
			return
		end
		self:SetPropagateKeyboardInput(false)
	end)



	exportEditBox:SetScript("OnKeyUp", function(self)
		self:SetPropagateKeyboardInput(false)
	end)
	exportEditBox:SetScript("OnMouseDown", function()
		copyHint:SetAlpha(0.3)
	end)



-- Scroll frame (moved slightly lower to avoid overlap)
local scrollFrame = CreateFrame("ScrollFrame", "GlowTrackerExportScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 20, -90)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 20)

exportEditBox = CreateFrame("EditBox", "GlowTrackerExportEditBox", scrollFrame)
exportEditBox:SetMultiLine(true)
exportEditBox:SetFontObject(ChatFontNormal)
exportEditBox:SetWidth(540)
exportEditBox:SetAutoFocus(false)
exportEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
scrollFrame:SetScrollChild(exportEditBox)

-- read‑only protection
exportEditBox:SetScript("OnKeyDown", function(self, key)
    if IsControlKeyDown() and (key == "C" or key == "A") then
        self:SetPropagateKeyboardInput(true)
        return
    end
    self:SetPropagateKeyboardInput(false)
end)

exportEditBox:SetScript("OnMouseDown", function()
    copyHint:SetAlpha(0.3)
end)


    if GlowTrackerDB.window.x ~= 0 and GlowTrackerDB.window.y ~= 0 then
        exportFrame:ClearAllPoints()
        exportFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", GlowTrackerDB.window.x, GlowTrackerDB.window.y)
    end

    if GlowTrackerDB.window.shown then
        exportFrame:Show()
    end

    GlowTracker_InitClassDropDown()
    GlowTracker_InitSpecDropDown()
    GlowTracker_UpdateExportText()

end

local function GlowTracker_ToggleExportWindow()
    if not exportFrame then
        GlowTracker_CreateExportWindow()
    end
    if exportFrame:IsShown() then
        exportFrame:Hide()
        GlowTrackerDB.window.shown = false
    else
        exportFrame:Show()
        GlowTrackerDB.window.shown = true
        GlowTracker_InitClassDropDown()
        GlowTracker_InitSpecDropDown()
        GlowTracker_UpdateExportText()
    end
end

SLASH_GLOWEXPORT1 = "/glowexport"
SlashCmdList["GLOWEXPORT"] = GlowTracker_ToggleExportWindow

-- Minimap button
local minimapButton = CreateFrame("Button", "GlowTrackerMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetMovable(true)
minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Cooldown\\star4")
icon:SetTexCoord(0, 1, 0, 1)
icon:SetAllPoints()

local mask = minimapButton:CreateMaskTexture()
mask:SetTexture("Interface\\Minimap\\UI-Minimap-Background") -- circular mask
mask:SetAllPoints(minimapButton)
icon:AddMaskTexture(mask)


local function GlowTracker_UpdateMinimapButtonPosition()
    if GlowTrackerDB.minimap.free then
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", GlowTrackerDB.minimap.x, GlowTrackerDB.minimap.y)
    else
        local angle = math.rad(GlowTrackerDB.minimap.angle or 45)
        local radius = 80
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
end

minimapButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local mx, my = Minimap:GetCenter()
    if IsShiftKeyDown() then
        GlowTrackerDB.minimap.free = true
        GlowTrackerDB.minimap.x = cx
        GlowTrackerDB.minimap.y = cy
    else
        GlowTrackerDB.minimap.free = false
        local dx, dy = cx - mx, cy - my
        local angle = math.deg(math.atan2(dy, dx))
        if angle < 0 then angle = angle + 360 end
        GlowTrackerDB.minimap.angle = angle
    end
    GlowTracker_UpdateMinimapButtonPosition()
end)

minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        GlowTracker_ToggleExportWindow()
    elseif button == "RightButton" then
        -- optional: reset to minimap
        GlowTrackerDB.minimap.free = false
        GlowTrackerDB.minimap.angle = 45
        GlowTracker_UpdateMinimapButtonPosition()
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("GlowTracker", 1, 1, 1)
    GameTooltip:AddLine("Left-click: Toggle export window", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-drag: Free move", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Snap around minimap", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Reset position", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

local fInit = CreateFrame("Frame")
fInit:RegisterEvent("PLAYER_LOGIN")
fInit:SetScript("OnEvent", function()
    GlowTracker_UpdateMinimapButtonPosition()
end)

SLASH_GLOWDUMP1 = "/glowdump"
SlashCmdList["GLOWDUMP"] = function()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    local specName = spec and select(2, GetSpecializationInfo(spec)):upper() or "NOSPEC"

    if not GlowSpellsDB[class] or not GlowSpellsDB[class][specName] then
        print("GlowTracker: No data for", class, specName)
        return
    end

    print("GlowTracker: Learned spells for", class, specName)

    for spellID, info in pairs(GlowSpellsDB[class][specName]) do
        local name = GetSpellInfo(spellID) or "Unknown"
        print(
            string.format(
                "  %d (%s) – Types: %s",
                spellID,
                name,
                table.concat((function()
                    local t = {}
                    for k in pairs(info.types) do table.insert(t, k) end
                    return t
                end)(), ", ")
            )
        )
    end
end
local function ExportGlowDB()
    print("GlowTracker Export Begin:")

    for class, specs in pairs(GlowSpellsDB) do
        print(class .. " = {")
        for spec, spells in pairs(specs) do
            print("  " .. spec .. " = {")
            for spellID, info in pairs(spells) do
                local name = GetSpellInfo(spellID) or "Unknown"
                print(string.format(
                    "    [%d] = { spell = %d, -- %s",
                    spellID, spellID, name
                ))
                print("      types = {")
                for t in pairs(info.types) do
                    print("        " .. t .. " = true,")
                end
                print("      },")
                print("      triggers = {")
                for trig in pairs(info.triggers) do
                    print("        [\"" .. trig .. "\"] = true,")
                end
                print("      },")
                print("    },")
            end
            print("  },")
        end
        print("},")
    end

    print("GlowTracker Export End.")
end

SLASH_GLOWEXPORT1 = "/glowexport"
SlashCmdList["GLOWEXPORT"] = ExportGlowDB

