GlowSpellsDB = GlowSpellsDB or {}

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
