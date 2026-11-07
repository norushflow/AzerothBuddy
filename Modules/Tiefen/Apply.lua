local _, Buddy = ...
local TB = Buddy.Tiefen

-- Blizzard erlaubt Änderungen an der Begleiterkonfiguration nur außerhalb des
-- Kampfes und während einer zulässigen Interaktion mit den Begleitervorräten.
-- Eine reine Annäherung ist über Addon-APIs nicht zuverlässig erkennbar:
-- ClosestUnitPosition ist laut Warcraft Wiki nur für Kreaturen in Startgebieten
-- aussagekräftig. Deshalb wird nur nach echten Interaktionssignalen geschrieben:
-- TRAIT_SYSTEM_INTERACTION_STARTED für den Begleitertraitbaum,
-- SHOW_DELVES_COMPANION_CONFIGURATION_UI und Anzeige des Begleiterfensters.
-- C_Traits.CanEditConfig bleibt zusätzliche Berechtigungsprüfung, ersetzt aber
-- nicht das Interaktionssignal.

local function record(value) return TB.Public(value) and type(value) == "table" end
local function number(value) return TB.Public(value) and type(value) == "number" end

-- Blizzards Panel-Refresh aktualisiert Rolle und Kuriositäten, aber nicht
-- einen bereits sichtbaren Flavor-Slot. Nur dessen veralteten Cache erneuern,
-- ohne Auswahl zu schreiben oder einen Blizzard-Klick zu simulieren.
function TB.SyncPoisonDisplay()
    if TB.InCombat() then return end
    TB.Foreign(_G.DelvesCompanionConfigurationFrame, function(panel)
        local shown=panel:IsShown()
        if not TB.Public(shown) or shown~=true then return end
        local slots=panel.CompanionSlots
        if not record(slots) then return end
        TB.Foreign(slots.CompanionFlavorSlot, function(slot)
            local visible=slot:IsShown()
            if not TB.Public(visible) or visible~=true then return end
            local config,nodeID=slot.configID,slot.selectionNodeID
            if not number(config) or not number(nodeID) or nodeID<=0 then return end
            if TB.Call(C_Traits,"ConfigHasStagedChanges",config)~=false then return end
            local live=TB.Call(C_Traits,"GetNodeInfo",config,nodeID)
            local cached=slot.selectionNodeInfo
            if not record(live) or not record(live.activeEntry)
                or not number(live.activeEntry.entryID) then return end
            if not record(cached) or not record(cached.activeEntry)
                or not number(cached.activeEntry.entryID) then return end
            if live.activeEntry.entryID~=cached.activeEntry.entryID
                and type(slot.Refresh)=="function" then slot:Refresh() end
        end)
    end)
end

local function ActiveEntry(config, nodeID)
    if not number(config) or not number(nodeID) then return end
    local node = TB.Call(C_Traits, "GetNodeInfo", config, nodeID)
    if not record(node) or not record(node.activeEntry) then return end
    if number(node.activeEntry.entryID) then return node.activeEntry.entryID end
end

local function ConfigHasTree(config, treeID)
    local info = TB.Call(C_Traits, "GetConfigInfo", config)
    if not record(info) or not record(info.treeIDs) then return false end
    for _, id in ipairs(info.treeIDs) do
        if number(id) and id == treeID then return true end
    end
    return false
end

-- Setzt die Schreibfreigabe ausschließlich nach einem Interaktionssignal.
-- Ohne Argument (Ereignis ohne Nutzdaten, z. B. SHOW_..._UI) gilt das
-- Begleiterfenster als geöffnet; mit treeID muss es ein Begleitertraitbaum
-- sein. Ein explizit übergebenes nil ist ungültig.
function TB.NoteInteraction(...)
    local count = select("#", ...)
    if count == 0 then
        TB.interacting, TB.interactionTree = true, nil
        return true
    end
    local treeID = ...
    if not number(treeID) then return false end
    if TB.Call(C_DelvesUI, "IsTraitTreeForCompanion", treeID) ~= true then return false end
    TB.interacting, TB.interactionTree = true, treeID
    return true
end

function TB.ClearInteraction()
    TB.interacting, TB.interactionTree = nil, nil
end

-- Dieselben Voraussetzungen wie in Blizzards Begleiterfenster, ergänzt um das
-- nachweisliche Interaktionssignal. Offene fremde Änderungen werden nicht
-- mit übernommen.
function TB.CanWrite(config)
    if not TB.db then return false, "notready" end
    if TB.InCombat() then return false, "combat" end
    if not TB.Context().inside then return false, "outside" end
    if not number(config) then return false, "unavailable" end
    -- Eine bloße Editierberechtigung belegt keine räumliche Nähe; ohne
    -- Interaktionssignal wird nicht geschrieben.
    if not TB.interacting then return false, "interaction" end
    if number(TB.interactionTree) and not ConfigHasTree(config, TB.interactionTree) then
        return false, "interaction"
    end
    if TB.Call(C_Traits, "CanEditConfig", config) ~= true then return false, "locked" end
    if TB.Call(C_Traits, "ConfigHasStagedChanges", config) ~= false then return false, "staged" end
    return true
end

-- Ermittelt nur die tatsächlich abweichenden, verfügbaren Auswahlen.
local function Plan(config, snapshot, recommendation)
    local changes, missing = {}, 0
    for index, slotKey in ipairs(TB.order) do
        local row = recommendation.rows and recommendation.rows[index]
        local live = snapshot.slots and snapshot.slots[slotKey]
        local nodeID = live and live.node
        if row and row.choice and row.choice.available == true and number(nodeID)
            and number(row.choice.entry) then
            if not row.match then
                changes[#changes + 1] = {node = nodeID, entry = row.choice.entry}
            end
        else
            missing = missing + 1
        end
    end
    return changes, missing
end

local function Rollback(config)
    TB.Call(C_Traits, "RollbackConfig", config)
end

-- Alle Abweichungen werden zunächst vorgemerkt und erst danach gemeinsam
-- übernommen. Bei einem Fehler wird der eigene Entwurf zurückgerollt.
local function Commit(config, changes)
    local staged = 0
    for _, change in ipairs(changes) do
        if TB.Call(C_Traits, "SetSelection", config, change.node, change.entry) ~= true then
            if staged > 0 then Rollback(config) end
            return false, "write"
        end
        staged = staged + 1
    end
    if staged == 0 then return true end
    if TB.Call(C_Traits, "IsReadyForCommit") ~= true or TB.InCombat() then
        Rollback(config)
        return false, "notready"
    end
    if TB.Call(C_Traits, "CommitConfig", config) ~= true then
        Rollback(config)
        return false, "commit"
    end
    return true
end

local function Verify(config, changes)
    if TB.Call(C_Traits, "ConfigHasStagedChanges", config) ~= false then return false end
    for _, change in ipairs(changes) do
        if ActiveEntry(config, change.node) ~= change.entry then return false end
    end
    return true
end

local function Message(style, text)
    TB.status = TB.styles[style] .. " · " .. text
end

-- Ein angefordeter Modus bleibt bis zur vollständigen Übernahme vorgemerkt.
-- Der Versuch läuft nur bei Moduswechsel, Kampfende und nachweislicher
-- Interaktion mit den Begleitervorräten, nicht in einem Timer oder OnUpdate.
function TB.TryApply()
    local style = TB.pendingStyle
    if not style or style ~= TB.style or not TB.styles[style] then return false, "idle" end
    if TB.InCombat() then
        Message(style, "Übernahme nach dem Kampf vorgemerkt.")
        return false, "combat"
    end
    local snapshot = TB.Snapshot()
    local player = TB.Player()
    local recommendation = TB.Recommend(player, style, snapshot)
    TB.snapshot, TB.player, TB.recommendation = snapshot, player, recommendation
    if TB.Call(C_Traits, "ConfigHasStagedChanges", snapshot.config) == false
        and recommendation.changes == 0 and recommendation.missing == 0 then
        TB.pendingStyle = nil
        Message(style, "Einstellungen übernommen.")
        return true, "done"
    end
    local config = snapshot.config
    if not number(config) then
        TB.status = TB.Public(snapshot.error) and snapshot.error
            or (TB.styles[style] .. " · Valeera ist noch nicht verfügbar; Übernahme vorgemerkt.")
        return false, "unavailable"
    end
    local allowed, reason = TB.CanWrite(config)
    if not allowed then
        if reason == "interaction" then
            Message(style, "Übernahme an den Begleitervorräten vorgemerkt.")
        elseif reason == "staged" then
            Message(style, "Offene Änderungen in Valeeras Konfiguration; Übernahme vorgemerkt.")
        elseif reason == "locked" then
            Message(style, "Konfiguration gesperrt; Übernahme vorgemerkt.")
        elseif reason ~= "combat" then
            Message(style, "Übernahme vorgemerkt.")
        end
        return false, reason
    end
    local changes, missing = Plan(config, snapshot, recommendation)
    if #changes == 0 then
        Message(style, "Gesperrte Auswahl bleibt offen; keine Änderung nötig.")
        return false, "missing"
    end
    local ok, failure = Commit(config, changes)
    if not ok then
        local reasons={write="WoW hat die Auswahl abgelehnt; Freischaltung und Begleitervorräte prüfen.",
            notready="Konfiguration noch nicht speicherbereit oder Kampf begonnen.",
            commit="WoW hat das Speichern abgelehnt; Auswahl bleibt vorgemerkt."}
        Message(style, reasons[failure] or "Übernahme nicht abgeschlossen; weiter vorgemerkt.")
        return false, failure
    end
    if not Verify(config, changes) then
        Message(style, "Übernahme wird geprüft; weiter vorgemerkt.")
        return false, "verify"
    end
    if missing > 0 or recommendation.changes > #changes then
        Message(style, "Teilweise übernommen; Gift oder Kuriosität gesperrt/nicht erkannt. Begleitervorräte prüfen.")
        return false, "partial"
    end
    TB.pendingStyle = nil
    Message(style, "Einstellungen übernommen.")
    return true, "done"
end

function TB.ApplyMode(style)
    if not TB.styles[style] then return false, "unknown" end
    TB.pendingStyle = style
    return TB.TryApply()
end

-- Wird beim normalen Aktualisieren nur lesend geprüft. Ein verspätet
-- bestätigter Commit löscht die Vormerkung, ohne erneut zu schreiben.
function TB.CheckPending(snapshot, recommendation)
    local style = TB.pendingStyle
    if not style or style ~= TB.style or not snapshot or not recommendation then return end
    if not number(snapshot.config) then return end
    if TB.Call(C_Traits, "ConfigHasStagedChanges", snapshot.config) == false
        and recommendation.changes == 0 and recommendation.missing == 0 then
        TB.pendingStyle = nil
        Message(style, "Einstellungen übernommen.")
    end
end
