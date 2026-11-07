-- Automatische Übernahme der Tiefenbegleiter-Modi auf Valeera.
-- Belegt Interaktionsgates, Vormerkung, Rollback und idempotentes Verhalten in LuaJIT.
-- Kein Client-, Taint-, Reichweiten- oder Optiknachweis.
local B = {Tiefen = {}}
local TB = B.Tiefen
local secret = setmetatable({}, {__tostring = function() error('secret formatted') end})
local function issecretvalue(value) return rawequal(value, secret) end

local combat, inside, canEdit = false, true, true
local snapshotConfig, snapshotError = 77, nil
local setCalls, commitCalls, rollbackCalls = 0, 0, 0
local failNode, commitApplies = nil, true
local unavailable = {}
local active = {[11] = 102, [12] = 202, [13] = 302, [14] = 403}
local staged = {}
local companionTrees = {[1223] = true}

local nodeIDs = {role = 11, poison = 12, combat = 13, utility = 14}
local options = {
    role = {{101, 'HEALER', 'Heiler'}, {102, 'TANK', 'Tank'}, {103, 'DAMAGER', 'Schaden'}},
    poison = {{201, 'frost', 'Frostherzgift'}, {202, 'toad', 'Aufplatzendes Krötengift'},
        {203, 'blood', 'Toxin der Blutgruft'}, {204, 'master', 'Gift des vergessenen Meisters'}},
    combat = {{301, 'idol', 'Viperwindgötze'}, {302, 'spear', 'Ätzender Gallenspeer'}},
    utility = {{401, 'dundun', 'Dunduns Gunst'}, {402, 'dream', 'Seelenknackender Traumfänger'},
        {403, 'totem', 'Staubiges Loatotem'}},
}

function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
function IsInInstance() return inside end
C_PartyInfo = {IsDelveInProgress = function() return inside end}
C_DelvesUI = {
    IsTraitTreeForCompanion = function(treeID) return companionTrees[treeID] == true end,
}
C_Traits = {
    CanEditConfig = function(config)
        assert(config == 77)
        if canEdit == nil then return nil end
        return canEdit, canEdit and '' or 'locked'
    end,
    ConfigHasStagedChanges = function(config) assert(config == 77); return next(staged) ~= nil end,
    GetConfigInfo = function(config) assert(config == 77); return {treeIDs = {1223}} end,
    SetSelection = function(config, node, entry)
        assert(config == 77)
        setCalls = setCalls + 1
        if node == failNode then return false end
        staged[node] = entry
        return true
    end,
    IsReadyForCommit = function() return true end,
    CommitConfig = function(config)
        assert(config == 77)
        commitCalls = commitCalls + 1
        if commitApplies then
            for node, entry in pairs(staged) do active[node] = entry end
        end
        staged = {}
        return true
    end,
    RollbackConfig = function(config) assert(config == 77); rollbackCalls = rollbackCalls + 1; staged = {}; return true end,
    GetNodeInfo = function(config, node)
        assert(config == 77)
        return {activeEntry = {entryID = active[node]}}
    end,
}

assert(loadfile('Modules/Tiefen/Game.lua'))('AzerothBuddy', B)
assert(loadfile('Modules/Tiefen/Rules.lua'))('AzerothBuddy', B)
assert(loadfile('Modules/Tiefen/Apply.lua'))('AzerothBuddy', B)
assert(TB.CanWrite and TB.TryApply and TB.ApplyMode and TB.CheckPending
    and TB.NoteInteraction and TB.ClearInteraction, 'write interface loaded')

TB.db = {}
TB.style = 'relaxed'
TB.Context = function() return {inside = inside} end
TB.Player = function() return {spec = 253, role = 'DAMAGER'} end

local function makeSnapshot()
    local slots = {}
    for _, slot in ipairs(TB.order) do
        local list, current = {}, nil
        for _, item in ipairs(options[slot]) do
            local option = {entry = item[1], key = item[2], name = item[3],
                available = not unavailable[item[1]]}
            list[#list + 1] = option
            if item[1] == active[nodeIDs[slot]] then current = option end
        end
        slots[slot] = {node = nodeIDs[slot], options = list, current = current}
    end
    return {config = snapshotConfig, companion = 1, error = snapshotError, slots = slots}
end

local function snapshot() return makeSnapshot() end
local function interact() assert(TB.NoteInteraction(1223), 'companion tree notes interaction') end
local function reset(style)
    TB.style = style or TB.style
    TB.pendingStyle = nil
    TB.status = nil
    TB.ClearInteraction()
    combat, inside, canEdit = false, true, true
    snapshotConfig, snapshotError = 77, nil
    setCalls, commitCalls, rollbackCalls = 0, 0, 0
    failNode, commitApplies = nil, true
    unavailable = {}
    staged = {}
    companionTrees = {[1223] = true}
end
local function mismatched()
    active = {[11] = 102, [12] = 202, [13] = 302, [14] = 403}
end
local function expected()
    return active[11] == 101 and active[12] == 201 and active[13] == 301 and active[14] == 401
end

-- 1) Moduswechsel nach Interaktion übernimmt Rolle, Gift und beide Kuriositäten.
reset('relaxed')
mismatched()
interact()
TB.Snapshot = snapshot
local ok, state = TB.ApplyMode('relaxed')
assert(ok and state == 'done', 'relaxed mode applied completely')
assert(setCalls == 4 and commitCalls == 1 and rollbackCalls == 0, 'one transaction for four slots')
assert(expected(), 'all four settings reached the live configuration')
assert(TB.pendingStyle == nil and TB.status:find('übernommen', 1, true), 'pending cleared after verified commit')

-- 2) Bereits korrekte Einstellungen lösen keinen Schreibzugriff aus.
reset('relaxed')
setCalls, commitCalls, rollbackCalls = 0, 0, 0
assert(TB.ApplyMode('relaxed') == true, 'already matching mode reports success')
assert(setCalls == 0 and commitCalls == 0 and rollbackCalls == 0, 'no writes when configuration already matches')

-- 3) Fehlende Valeera-Konfiguration bleibt vorgemerkt und folgt später.
reset('relaxed')
mismatched()
interact()
snapshotConfig = nil
snapshotError = 'Valeeras Einstellungen laden noch.'
TB.Snapshot = snapshot
assert(not TB.ApplyMode('relaxed') and setCalls == 0, 'unavailable companion never written')
assert(TB.pendingStyle == 'relaxed' and TB.status:find('laden', 1, true), 'pending keeps original load error')
snapshotConfig, snapshotError = 77, nil
assert(TB.TryApply() == true and expected() and TB.pendingStyle == nil, 'pending mode applied on next attempt')

-- 4) Im Kampf keine Änderung; nach dem Kampf wird die Vormerkung übernommen.
reset('relaxed')
mismatched()
interact()
combat = true
assert(not TB.ApplyMode('relaxed') and setCalls == 0, 'combat blocks every write')
assert(TB.pendingStyle == 'relaxed' and TB.status:find('Kampf', 1, true), 'combat keeps pending mode')
combat = false
assert(TB.TryApply() == true and expected() and TB.pendingStyle == nil, 'combat end applies pending mode')

-- 5) Ohne Interaktionssignal keine Änderung; das nächste Signal übernimmt.
reset('relaxed')
mismatched()
local allowed, reason = TB.ApplyMode('relaxed')
assert(not allowed and reason == 'interaction' and setCalls == 0, 'no write without interaction')
assert(TB.pendingStyle == 'relaxed' and TB.status:find('vorräten', 1, true),
    'mode stays pending until supplies interaction')
assert(TB.NoteInteraction(999) == false, 'foreign trait tree is not an interaction')
assert(TB.NoteInteraction(nil) == false, 'explicit nil tree is rejected')
assert(TB.NoteInteraction('1223') == false, 'non-numeric tree is rejected')
assert(not TB.interacting and setCalls == 0, 'rejected signals grant no write permission')
interact()
assert(TB.TryApply() == true and expected() and TB.pendingStyle == nil,
    'next supplies interaction applies pending mode')

-- 6) Das nutzdatenlose UI-Ereignis gilt als Interaktion.
reset('relaxed')
mismatched()
assert(not TB.ApplyMode('relaxed') and setCalls == 0, 'UI signal still required')
assert(TB.NoteInteraction() == true, 'payload-free UI interaction accepted')
assert(TB.TryApply() == true and expected() and TB.pendingStyle == nil, 'UI interaction applies pending mode')

-- 7) Interaktion für einen anderen Begleitertraitbaum schreibt nicht.
reset('relaxed')
mismatched()
assert(not TB.ApplyMode('relaxed'))
companionTrees[1333] = true
assert(TB.NoteInteraction(1333) == true, 'other companion tree notes interaction')
assert(not TB.TryApply() and setCalls == 0, 'mismatched companion tree never writes')
assert(TB.pendingStyle == 'relaxed', 'mismatched tree keeps mode pending')
interact()
assert(TB.TryApply() == true and expected(), 'matching companion tree applies pending mode')

-- 8) Eine beendete Interaktion sperrt weitere Schreibversuche.
reset('relaxed')
mismatched()
interact()
TB.ClearInteraction()
assert(not TB.ApplyMode('relaxed') and setCalls == 0, 'closed interaction never writes')
assert(TB.pendingStyle == 'relaxed', 'closed interaction keeps mode pending')

-- 9) Gesperrte Kuriosität: nur verfügbare Slots werden geschrieben, danach idempotent.
reset('relaxed')
mismatched()
interact()
for _, entry in ipairs({201, 202, 203, 204}) do unavailable[entry] = true end
assert(not TB.ApplyMode('relaxed') and setCalls == 3 and commitCalls == 1, 'only available slots staged')
assert(active[11] == 101 and active[13] == 301 and active[14] == 401 and active[12] == 202,
    'available slots applied, locked poison untouched')
assert(TB.pendingStyle == 'relaxed', 'locked curio keeps mode pending')
assert(not TB.TryApply() and setCalls == 3 and commitCalls == 1, 'second attempt performs no repeated writes')
unavailable = {}
assert(TB.TryApply() == true and active[12] == 201 and TB.pendingStyle == nil,
    'newly available poison is applied later')

-- 10) Fehlgeschlagenes SetSelection rollt den eigenen Entwurf zurück.
reset('relaxed')
mismatched()
interact()
failNode = 12
assert(not TB.ApplyMode('relaxed') and rollbackCalls == 1 and commitCalls == 0, 'failed selection rolls back')
assert(active[11] == 102 and TB.pendingStyle == 'relaxed', 'rollback leaves live config untouched')
failNode = nil
assert(TB.TryApply() == true and expected(), 'retry after rollback succeeds')

-- 11) Fremde offene Änderungen werden weder übernommen noch verworfen.
reset('relaxed')
mismatched()
interact()
staged[99] = 999
assert(not TB.ApplyMode('relaxed') and setCalls == 0 and commitCalls == 0 and rollbackCalls == 0,
    'foreign staged changes are left alone')
assert(TB.pendingStyle == 'relaxed', 'foreign changes keep mode pending')
staged = {}
assert(TB.TryApply() == true and expected(), 'pending mode follows after foreign changes are gone')

-- 12) Sperre der Konfiguration verhindert Schreiben.
reset('relaxed')
mismatched()
interact()
canEdit = false
assert(not TB.ApplyMode('relaxed') and setCalls == 0 and commitCalls == 0, 'locked config is not written')
assert(TB.pendingStyle == 'relaxed', 'locked config keeps pending mode')
canEdit = true
assert(TB.TryApply() == true and expected(), 'unlocked config applies pending mode')

-- 13) Fehlende oder geheime Editierberechtigung gilt nicht als erlaubt.
reset('relaxed')
mismatched()
interact()
canEdit = nil
assert(not TB.ApplyMode('relaxed') and setCalls == 0, 'missing edit permission is not allowed')
assert(TB.pendingStyle == 'relaxed', 'missing permission keeps mode pending')
canEdit = secret
assert(not TB.TryApply() and setCalls == 0, 'secret edit permission is not compared')
canEdit = true
assert(TB.TryApply() == true and expected(), 'clear permission applies pending mode')

-- 14) Verzögerte Bestätigung: keine erneute Schreibrunde, nur Leseprüfung.
reset('relaxed')
mismatched()
interact()
commitApplies = false
assert(not TB.ApplyMode('relaxed') and setCalls == 4 and commitCalls == 1, 'commit sent once')
assert(TB.pendingStyle == 'relaxed', 'unconfirmed commit keeps pending mode')
active = {[11] = 101, [12] = 201, [13] = 301, [14] = 401}
local review = TB.Recommend(TB.Player(), 'relaxed', snapshot())
TB.CheckPending(snapshot(), review)
assert(TB.pendingStyle == nil and setCalls == 4 and commitCalls == 1, 'confirmed commit clears pending without writes')

-- 15) Erneuter Moduswechsel ersetzt die Vormerkung und schreibt nur die Abweichung.
reset('relaxed')
active = {[11] = 101, [12] = 201, [13] = 301, [14] = 401}
interact()
assert(TB.ApplyMode('relaxed') == true and setCalls == 0, 'relaxed remains current')
TB.style = 'fast' -- entspricht dem Moduswechsel über TB.SetStyle
assert(TB.ApplyMode('fast') == true, 'fast mode applied from current state')
assert(setCalls == 1 and commitCalls == 1 and active[12] == 202, 'only changed poison selected')
assert(TB.pendingStyle == nil, 'fast mode fully confirmed')

-- 16) Die bestehende Preset-Logik bestimmt die Rolle (Heiler -> Tank).
reset('relaxed')
active = {[11] = 103, [12] = 202, [13] = 302, [14] = 403}
interact()
TB.Player = function() return {spec = 253, role = 'HEALER'} end
assert(TB.ApplyMode('relaxed') == true and active[11] == 102, 'healer player receives the tank role')
TB.Player = function() return {spec = 253, role = 'DAMAGER'} end

-- 17) Außerhalb einer Tiefe wird auch mit Interaktionssignal nicht geschrieben.
reset('relaxed')
mismatched()
interact()
inside = false
assert(not TB.ApplyMode('relaxed') and setCalls == 0, 'outside delve no writes')
assert(TB.pendingStyle == 'relaxed', 'outside delve keeps pending mode')

print('PASS: interaction-gated takeover, pending retry, combat/lock gates, rollback and idempotence')
