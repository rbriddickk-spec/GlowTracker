--GlowSpellsDB   = GlowSpellsDB   or {}
GlowTrackerDB  = GlowTrackerDB  or {}
GlowTrackerDB.glows = GlowTrackerDB.glows or {}
GlowTrackerDB.migratedLegacyToGlows = GlowTrackerDB.migratedLegacyToGlows or false
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

local function AddGlow(spellID)
    if type(spellID) ~= "number" then return end
    local class, spec = GetSpecKey()
    GlowTrackerDB.glows[class] = GlowTrackerDB.glows[class] or {}
    GlowTrackerDB.glows[class][spec] = GlowTrackerDB.glows[class][spec] or {}
    GlowTrackerDB.glows[class][spec][spellID] = true
end

local function MigrateLegacyGlowSpellsDB()
    if GlowTrackerDB.migratedLegacyToGlows then return end
    if type(GlowSpellsDB) ~= "table" then
        GlowTrackerDB.migratedLegacyToGlows = true
        return
    end

    for class, specs in pairs(GlowSpellsDB) do
        if type(specs) == "table" then
            GlowTrackerDB.glows[class] = GlowTrackerDB.glows[class] or {}
            for spec, spells in pairs(specs) do
                if type(spells) == "table" then
                    GlowTrackerDB.glows[class][spec] = GlowTrackerDB.glows[class][spec] or {}
                    for spellID in pairs(spells) do
                        local numericSpellID = tonumber(spellID)
                        if numericSpellID then
                            GlowTrackerDB.glows[class][spec][numericSpellID] = true
                        end
                    end
                end
            end
        end
    end
    GlowTrackerDB.migratedLegacyToGlows = true
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        MigrateLegacyGlowSpellsDB()
    end

    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellID = ...
        AddGlow(spellID)
    end

    if event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE" then
        for slot = 1, 120 do
            local actionType, id = GetActionInfo(slot)
            if actionType == "spell" and id then
                if IsSpellOverlayed(id) then
                    AddGlow(id)
                end
            end
        end
    end
end)
local exportFrame, exportEditBox, classDropDown, copyHint
local lastExportText = ""

local function GlowTracker_GetClassSpecList()
    local classes = {}
    for class, specs in pairs(GlowTrackerDB.glows) do
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

local function GlowTracker_BuildExportText(class)
    local classSpecs = class and GlowTrackerDB.glows[class]
    if type(classSpecs) ~= "table" then
        return "-- No data for " .. (class or "Class")
    end

    local specNames = {}
    for spec in pairs(classSpecs) do
        table.insert(specNames, spec)
    end
    table.sort(specNames)

    local lines = {}
    for _, spec in ipairs(specNames) do
        local sorted = {}
        local specSpells = classSpecs[spec]
        if type(specSpells) == "table" then
            for spellID in pairs(specSpells) do
                local name = GetSpellInfo(spellID) or "Unknown"
                table.insert(sorted, { spellID = spellID, name = name })
            end
        end
        table.sort(sorted, function(a, b)
            local aLower = string.lower(a.name)
            local bLower = string.lower(b.name)
            if aLower == bLower then
                return a.spellID < b.spellID
            end
            return aLower < bLower
        end)

        if #sorted > 0 then
            table.insert(lines, spec)
            for _, entry in ipairs(sorted) do
                table.insert(lines, string.format("%s = %d", entry.name, entry.spellID))
            end
            table.insert(lines, "")
        end
    end

    if #lines == 0 then
        return "-- No data for " .. class
    else
        table.remove(lines)
        return table.concat(lines, "\n")
    end
end

local currentClass


local function GlowTracker_RefreshEditBoxSize()
    if not exportEditBox then return end

    local width = 540
    exportEditBox:SetWidth(width)

    -- Prefer measuring the underlying FontString (more compatible than EditBox:GetStringHeight())
    local fs = exportEditBox.GetFontString and exportEditBox:GetFontString()
    local textHeight = 0

    if fs and fs.GetStringHeight then
        textHeight = fs:GetStringHeight() or 0
    end

    -- Keep a minimum height so the box doesn't collapse on first open / empty text
    local minHeight = 200
    local padding = 20
    local h = textHeight + padding
    if h < minHeight then h = minHeight end

    exportEditBox:SetHeight(h)
end

local function GlowTracker_UpdateExportText()
    if not exportEditBox or not currentClass then return end

   local text = GlowTracker_BuildExportText(currentClass)
		lastExportText = text or ""
		exportEditBox:SetText(lastExportText)
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

-- Ctrl+C indicator text (create first)
copyHint = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
copyHint:SetPoint("LEFT", classDropDown, "RIGHT", 210, 0)
copyHint:SetText("Press Ctrl+C")
copyHint:SetAlpha(0.3)

-- Select All button (left of the hint)
local selectAllBtn = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
selectAllBtn:SetSize(80, 22)
selectAllBtn:SetPoint("LEFT", classDropDown, "RIGHT", 120, 0)
selectAllBtn:SetText("Select All")
selectAllBtn:SetScript("OnClick", function()
    if exportEditBox then
        exportEditBox:HighlightText()
        exportEditBox:SetFocus()
        if copyHint then
            copyHint:SetAlpha(1)
        end
    end
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

-- read-only protection (allow selection + Ctrl+C/Ctrl+A, prevent edits)
exportEditBox:SetScript("OnKeyDown", function(self, key)
    -- Allow copy/select-all
    if IsControlKeyDown() and (key == "C" or key == "A") then
        self:SetPropagateKeyboardInput(true)
        return
    end

    -- Block keys that commonly modify the EditBox
    if key == "BACKSPACE" or key == "DELETE" or key == "SPACE" or key == "ENTER" then
        self:SetPropagateKeyboardInput(false)
        if self:GetText() ~= lastExportText then
            self:SetText(lastExportText)
        end
        self:HighlightText(0, 0)
        self:SetCursorPosition(0)
        return
    end

    -- Block everything else (mouse selection still works)
    self:SetPropagateKeyboardInput(false)
end)

-- If text changes due to user input anyway, revert immediately
exportEditBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
        self:SetText(lastExportText)
        self:HighlightText(0, 0)
        self:SetCursorPosition(0)
    end
end)

exportEditBox:SetScript("OnMouseDown", function()
    if copyHint then
        copyHint:SetAlpha(0.3)
    end
end)


    if GlowTrackerDB.window.x ~= 0 and GlowTrackerDB.window.y ~= 0 then
        exportFrame:ClearAllPoints()
        exportFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", GlowTrackerDB.window.x, GlowTrackerDB.window.y)
    end

    if GlowTrackerDB.window.shown then
        exportFrame:Show()
    end

    GlowTracker_InitClassDropDown()
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

    if not GlowTrackerDB.glows[class] or not GlowTrackerDB.glows[class][specName] then
        print("GlowTracker: No data for", class, specName)
        return
    end

    print("GlowTracker: Learned spells for", class, specName)

    for spellID in pairs(GlowTrackerDB.glows[class][specName]) do
        local name = GetSpellInfo(spellID) or "Unknown"
        print(string.format("  %s = %d", name, spellID))
    end
end
local function ExportGlowDB()
    print("GlowTracker Export Begin:")

    for class, specs in pairs(GlowTrackerDB.glows) do
        print(class .. " = {")
        for spec, spells in pairs(specs) do
            print("  " .. spec .. " = {")
            for spellID in pairs(spells) do
                local name = GetSpellInfo(spellID) or "Unknown"
                print(string.format("    %s = %d,", name, spellID))
            end
            print("  },")
        end
        print("},")
    end

    print("GlowTracker Export End.")
end

-- NOTE: /glowexport is reserved for toggling the export window above.
-- If you want to print the export to chat, call ExportGlowDB() from /glowdump
-- or add a separate slash command here.
