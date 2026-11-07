local _, Buddy = ...
local TB = Buddy.Tiefen
TB.order = {"role", "poison", "combat", "utility"}
TB.labels = {role="Kampfrolle", poison="Gift", combat="Kampfkuriosität", utility="Unterstützung"}
TB.styles = {relaxed="Entspannt", safe="Sicher", fast="Tempo"}
TB.catalog = {
    idol = {name="Viperwindgötze", names={"Viperwindgötze", "Viperwindidol", "Viperwind-Idol", "Viperwind Idol"}, spells={1288795,1314568}},
    spear = {name="Ätzender Gallenspeer", names={"Ätzender Gallenspeer", "Corrosive Bilespear"}, spells={1248877,1305643}},
    dundun = {name="Dunduns Gunst", names={"Dunduns Gunst", "Dundun's Favor", "Dundun’s Favor"}},
    dream = {name="Seelenknackender Traumfänger", names={"Seelenknackender Traumfänger", "Soul-Cracking Dreamcatcher"}, spells={1248898,1248939}},
    totem = {name="Staubiges Loatotem", names={"Staubiges Loatotem", "Staubiges Loa-Totem", "Dusty Loa Totem"}, spells={1288801,1314974,1314978}},
    frost = {name="Frostherzgift", names={"Frostherzgift", "Frostheart Venom", "Frostheart Poison"}, spells={1298137}},
    toad = {name="Aufplatzendes Krötengift", names={"Aufplatzendes Krötengift", "Bursting Toad Toxin", "Bursting Toad Poison"}, spells={1305904,1305906,1306740}},
    blood = {name="Toxin der Blutgruft", names={"Toxin der Blutgruft", "Bloodcrypt Toxin", "Blood Crypt Toxin"}, spells={1251111,1251113}},
    master = {name="Gift des vergessenen Meisters", names={"Gift des vergessenen Meisters", "Poison of the Forgotten Master"}},
}
TB.roleNames = {HEALER="Heiler", TANK="Tank", DAMAGER="Schaden"}
-- Class-specific guidance is deliberately limited to the user's Hunter specs.
-- Other classes use explicit role-based presets, not claimed spec simulations.
TB.hunters = {
    [253] = "Dein Tier bindet Gegner; Valeera hält dich als Heilerin stabil.",
    [254] = "Heilerin für ruhige Solorunden. Ohne tankendes Tier ist Tank-Valeera eine Alternative.",
    [255] = "Als Nahkämpfer profitierst du von Heilung und gebremsten Gegnern.",
}

local replacements={["Ä"]="ae",["ä"]="ae",["Ö"]="oe",["ö"]="oe",["Ü"]="ue",["ü"]="ue",["ß"]="ss",["’"]=""}
function TB.Normalize(text)
    text = not (issecretvalue and issecretvalue(text)) and type(text) == "string" and text or ""
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for from, to in pairs(replacements) do
        text = text:gsub(from, to)
    end
    return text:lower():gsub("[%s%p]", "")
end

local bySpell,byName,localizedNames={},{},{}
for key,item in pairs(TB.catalog) do
    for _,id in ipairs(item.spells or {}) do bySpell[id]=key end
    for _,name in ipairs(item.names) do byName[TB.Normalize(name)]=key end
end
function TB.Identify(option)
    if option.role then return option.role end
    if not (issecretvalue and issecretvalue(option.spell)) and bySpell[option.spell] then return bySpell[option.spell] end
    local normalized=TB.Normalize(option.name)
    if normalized=="" then return end
    if byName[normalized] then return byName[normalized] end
    -- Cache only successful localized lookups; unloaded spell data is retried.
    for id,key in pairs(bySpell) do
        local name=localizedNames[id]
        if not name then
            local spell=TB.Call(C_Spell,"GetSpellInfo",id)
            name=spell and TB.Normalize(spell.name)
            if name and name~="" then localizedNames[id]=name end
        end
        if name==normalized then return key end
    end
end

function TB.Preset(player, style)
    local safe, fast = style == "safe", style == "fast"
    local role = player.role == "HEALER" and "TANK" or "HEALER"
    if player.role == "TANK" and not safe then role = "DAMAGER" end
    local reason = TB.hunters[player.spec]
        or (player.role == "HEALER" and "Du heilst, Valeera bindet die Gegner als Tank.")
        or (player.role == "TANK" and (safe and "Zusätzliche Heilung für vorsichtige Runden." or "Du tankst, Valeera ergänzt Schaden."))
        or "Heilung als Ausgangspunkt für entspannte Solorunden."
    return {
        role={role},
        poison=safe and {"frost", "blood"} or fast and {"toad", "master", "blood"} or {"frost", "blood", "toad"},
        combat={"idol", "spear"},
        utility=safe and {"totem", "dream", "dundun"} or {"dundun", "dream", "totem"},
        reason=reason,
    }
end

function TB.Name(key)
    return TB.roleNames[key] or (TB.catalog[key] and TB.catalog[key].name) or "Noch nicht erkannt"
end

function TB.Recommend(player, style, snapshot)
    local preset = TB.Preset(player, style)
    local result = {rows={}, reason=preset.reason, changes=0, missing=0}
    for _, slot in ipairs(TB.order) do
        local live = snapshot.slots and snapshot.slots[slot]
        local selected, fallback
        for rank, key in ipairs(preset[slot]) do
            for _, option in ipairs(live and live.options or {}) do
                if option.key==key and option.available then selected=option; fallback=rank>1; break end
            end
            if selected then break end
        end
        local current = live and live.current
        local match = selected and current and selected.entry==current.entry
        result.rows[#result.rows+1] = {slot=slot, current=current, choice=selected,
            name=selected and selected.name or TB.Name(preset[slot][1]),
            fallback=fallback, match=match==true}
        if not selected then result.missing=result.missing+1
        elseif not match then result.changes=result.changes+1 end
    end
    return result
end
