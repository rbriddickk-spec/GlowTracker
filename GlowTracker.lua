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

