local _, Buddy = ...
local L = Buddy.L
local TB = Buddy.Tiefen

function TB.Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function record(value) return TB.Public(value) and type(value)=="table" end
local function number(value) return TB.Public(value) and type(value)=="number" end
local function text(value) return TB.Public(value) and type(value)=="string" end

function TB.Call(owner, name, ...)
    local fn = owner and owner[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and TB.Public(value) then return value end
end

-- Fremde Blizzard-Fenster nur über pcall und IsForbidden anfassen. Rückgabe
-- ist (ok, value); bei geschütztem oder unbekanntem Frame bleibt ok false.
function TB.Foreign(frame, fn)
    if not TB.Public(frame) or not frame or type(fn) ~= "function" then return false end
    local ok, value = pcall(function()
        local forbidden = frame:IsForbidden()
        if not TB.Public(forbidden) or forbidden then error("forbidden") end
        return fn(frame)
    end)
    if not ok then return false end
    return true, value
end

function TB.InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

function TB.Player()
    local index = GetSpecialization and GetSpecialization()
    local id, name, _, _, role
    if number(index) and GetSpecializationInfo then id, name, _, _, role = GetSpecializationInfo(index) end
    local className, class = UnitClass("player")
    return {spec=number(id) and id or 0, name=text(name) and name or L["Spezialisierung lädt"],
        role=text(role) and role or "DAMAGER", class=text(class) and class or nil,
        className=text(className) and className or nil}
end

-- Gemeinsame Eintrittserkennung für den reinen Berater.
-- Keine Tiefenliste, Stufen-/Widget-, Ressourcen- oder Wegpunktabfragen.
function TB.Context()
    local inside = TB.Call(_G, "IsInInstance") == true
    local inDelve = inside and TB.Call(C_PartyInfo, "IsDelveInProgress") == true
    if inside and not inDelve then
        local scenario = TB.Call(C_Scenario, "GetInfo")
        inDelve = text(scenario) and text(_G.DELVES_LABEL) and scenario==_G.DELVES_LABEL
    end
    return {inside=inDelve==true}
end

local function ReadOption(config, entryID, node)
    if not number(entryID) then return end
    local entry = TB.Call(C_Traits, "GetEntryInfo", config, entryID)
    if not record(entry) then return end
    local option = {entry=entryID, available=TB.Public(entry.isAvailable) and entry.isAvailable==true
        and TB.Public(node.isVisible) and node.isVisible~=false
        and TB.Public(node.isAvailable) and node.isAvailable~=false}
    if number(entry.subTreeID) and entry.subTreeID>0 then
        local sub = TB.Call(C_Traits, "GetSubTreeInfo", config, entry.subTreeID)
        option.name = record(sub) and text(sub.name) and sub.name or nil
        option.subtree = entry.subTreeID
    elseif number(entry.definitionID) then
        local def = TB.Call(C_Traits, "GetDefinitionInfo", entry.definitionID)
        if record(def) then
            option.spell = number(def.overriddenSpellID) and def.overriddenSpellID>0 and def.overriddenSpellID or
                (number(def.spellID) and def.spellID or nil)
            local spell = option.spell and TB.Call(C_Spell, "GetSpellInfo", option.spell)
            option.name = text(def.overrideName) and def.overrideName or
                (record(spell) and text(spell.name) and spell.name or nil)
        end
    end
    for _, conditionID in ipairs(record(entry.conditionIDs) and entry.conditionIDs or {}) do
        if number(conditionID) then
            local condition = TB.Call(C_Traits, "GetConditionInfo", config, conditionID, true)
            if record(condition) and number(condition.traitCondAccountElementID) then
                local rarity = TB.Call(C_DelvesUI, "GetCurioRarityByTraitCondAccountElementID", condition.traitCondAccountElementID)
                if number(rarity) and rarity>=1 and rarity<=5 then option.rank=rarity end
            end
        end
    end
    option.name = option.name or (L["Eintrag "] .. entryID)
    return option
end

function TB.Snapshot()
    local result = {slots={}}
    if TB.InCombat() then result.error=L["Im Kampf pausiert die Erkennung."]; return result end
    -- Blizzard-Fenster nur gesichert lesen. Fehlt der Zugriff, arbeitet die
    -- Erkennung vollständig über die Begleiter-API weiter.
    local native = {}
    TB.Foreign(_G.DelvesCompanionConfigurationFrame, function(panel)
        local shown = panel:IsShown()
        if not TB.Public(shown) or shown~=true then return end
        local slots = panel.CompanionSlots
        local role
        if record(slots) then
            pcall(function() role = slots.CompanionCombatRoleSlot end)
        end
        local info = panel.companionInfo
        native.shown = true
        native.slots = slots
        native.companion = panel.playerCompanionID
        TB.Foreign(role, function(slot) native.config = slot.configID end)
        native.name = record(info) and info.name or nil
    end)
    local shown = native.shown == true
    local nativeSlots = native.slots
    local companion = native.companion
    if not TB.Public(companion) or type(companion)~="number" then companion=TB.Call(C_DelvesUI,"GetCompanionInfoForActivePlayer") end
    if type(companion)~="number" then companion=nil end
    -- Companion ID 0 and the API's nil/default argument are both valid. The
    -- visible Blizzard configuration may also differ from the active mirror.
    local name = TB.Public(native.name) and type(native.name)=="string" and native.name or nil
    local visibleValeera = type(name)=="string" and TB.Normalize(name):find("valeera",1,true)~=nil
    local visibleOther = type(name)=="string" and name~="" and not visibleValeera
    local faction = TB.Call(C_DelvesUI,"GetFactionForCompanion",companion)
    local nativeConfig = TB.Public(native.config) and type(native.config)=="number" and native.config or nil
    local configInfo = nativeConfig and TB.Call(C_Traits,"GetConfigInfo",nativeConfig)
    local nativeValeera=false
    for _,treeID in ipairs(record(configInfo) and record(configInfo.treeIDs) and configInfo.treeIDs or {}) do
        if number(treeID) and treeID==1223 then nativeValeera=true end
    end
    if visibleOther or (not visibleValeera and not nativeValeera and faction~=2744) then
        result.error=L["Hier ist ein anderer Begleiter aktiv. Dieser Berater ist für Valeera."]; return result
    end
    result.companion = companion
    local useNative=shown and (visibleValeera or nativeValeera)
    local tree = useNative and 1223 or TB.Call(C_DelvesUI,"GetTraitTreeForCompanion",companion)
    result.config = (useNative and nativeConfig) or (tree and TB.Call(C_Traits,"GetConfigIDByTreeID",tree))
    result.source=useNative and L["Valeera-Fenster"] or L["Begleiter-API"]
    if not number(result.config) then result.error=L["Valeeras Einstellungen laden noch. Öffne ihre Begleitervorräte."]; return result end
    local ranks = TB.Call(C_GossipInfo, "GetFriendshipReputationRanks", 2744)
    result.level = record(ranks) and number(ranks.currentLevel) and ranks.currentLevel or nil
    local types = Enum and Enum.CurioType or {Combat=0, Utility=1}
    local nodes = {
        role=TB.Call(C_DelvesUI, "GetRoleNodeForCompanion", companion),
        poison=TB.Call(C_DelvesUI, "GetFlavorNodeForCompanion", companion),
        combat=TB.Call(C_DelvesUI, "GetCurioNodeForCompanion", types.Combat, companion),
        utility=TB.Call(C_DelvesUI, "GetCurioNodeForCompanion", types.Utility, companion),
    }
    if useNative and record(nativeSlots) then
        for key,field in pairs({role="CompanionCombatRoleSlot",poison="CompanionFlavorSlot",combat="CompanionCombatTrinketSlot",utility="CompanionUtilityTrinketSlot"}) do
            -- Auch der Zugriff auf den Slotcontainer kann scheitern.
            pcall(function()
            TB.Foreign(nativeSlots[field], function(slot)
                local slotConfig, selection = slot.configID, slot.selectionNodeID
                -- Vor Vergleich und Typcheck auf geheime Werte prüfen.
                if not TB.Public(slotConfig) or not TB.Public(selection) then return end
                if type(slotConfig)=="number" and slotConfig==result.config and type(selection)=="number" then nodes[key]=selection end
            end)
            end)
        end
    end
    local roleTypes = Enum and Enum.CompanionRoleType or {Dps=0, Heal=1, Tank=2}
    local roles = {}
    for key, value in pairs({DAMAGER=roleTypes.Dps, HEALER=roleTypes.Heal, TANK=roleTypes.Tank}) do
        local subtree = TB.Call(C_DelvesUI, "GetRoleSubtreeForCompanion", value, companion)
        if number(subtree) and subtree>0 then roles[subtree]=key end
    end
    for _, key in ipairs(TB.order) do
        local id = nodes[key]
        local node = number(id) and id>0 and TB.Call(C_Traits, "GetNodeInfo", result.config, id)
        if record(node) then
            local slot = {node=id, options={}}
            for _, entry in ipairs(record(node.entryIDs) and node.entryIDs or {}) do
                local option = ReadOption(result.config, entry, node)
                if option then
                    if key=="role" then
                        option.role=roles[option.subtree]
                        local roleName=TB.Normalize(option.name)
                        if roleName=="heiler" or roleName=="healer" then option.role="HEALER"
                        elseif roleName=="tank" then option.role="TANK"
                        elseif roleName=="schadensklasse" or roleName=="schaden" or roleName=="damage" or roleName=="damagedealer" then option.role="DAMAGER" end
                    end
                    option.key=TB.Identify(option)
                    slot.options[#slot.options+1]=option
                    if record(node.activeEntry) and number(node.activeEntry.entryID) and node.activeEntry.entryID==entry then slot.current=option end
                end
            end
            result.slots[key]=slot
        end
    end
    if not result.slots.role or not result.slots.poison or not result.slots.combat or not result.slots.utility then
        result.error=L["Valeeras Auswahl lädt noch. Öffne die Begleitervorräte und klicke „Valeera neu einlesen“."]
    end
    return result
end

function TB.OpenCompanion()
    if not TB.active or not TB.Context().inside then return end
    if TB.InCombat() then TB.Message(L["Öffne Valeera nach dem Kampf."]); return end
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_DelvesCompanionConfiguration") end
    local frame = _G.DelvesCompanionConfigurationFrame
    local opened = frame and type(ShowUIPanel)=="function" and TB.Foreign(frame,function(f) ShowUIPanel(f) end)
    if not opened then TB.Message(L["Klicke die Begleitervorräte in der Tiefe an."]) end
end
