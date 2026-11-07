local _, Buddy = ...
local TB = Buddy.Tiefen
local events = CreateFrame("Frame")
local queued
-- Ein Controller: außerhalb nur Eintritt/Austritt beobachten, Details nur innen.
local watch = {PLAYER_ENTERING_WORLD=true, ZONE_CHANGED_NEW_AREA=true, ZONE_CHANGED=true,
    SCENARIO_UPDATE=true, ACTIVE_DELVE_DATA_UPDATE=true, WALK_IN_DATA_UPDATE=true,
    PLAYER_REGEN_ENABLED=true}
local details = {"ADDON_LOADED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE",
    "PLAYER_REGEN_DISABLED", "TRAIT_CONFIG_UPDATED", "DELVES_ACCOUNT_DATA_ELEMENT_CHANGED",
    "SHOW_DELVES_COMPANION_CONFIGURATION_UI", "TRAIT_SYSTEM_INTERACTION_STARTED",
    "TRAIT_SYSTEM_NPC_CLOSED", "TRAIT_COND_INFO_CHANGED", "GROUP_ROSTER_UPDATE", "UPDATE_FACTION",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}

function TB.Message(text) Buddy.Message("Valeera: "..text) end
function TB.SetActive(active)
    if active and TB.InCombat() then return end
    if TB.active==active then return end
    TB.active=active; TB.visibility=nil; TB.status=nil
    if not active and TB.ClearInteraction then TB.ClearInteraction() end
    for _,event in ipairs(details) do
        if active then pcall(events.RegisterEvent,events,event)
        else events:UnregisterEvent(event) end
    end
    if active then
        if not TB.panel then TB.CreateUI(); TB.Place() end
    elseif TB.panel then TB.panel:Hide() end
end

function TB.Refresh()
    if not TB.db then return end
    local inside=TB.Context().inside
    TB.SetActive(inside)
    if not inside or TB.InCombat() then return end
    TB.UpdateVisibility()
    local native=_G.DelvesCompanionConfigurationFrame
    if native and TB.boundPanel~=native then
        local ok=TB.Foreign(native,function(frame)
            frame:HookScript("OnShow",function()
                if TB.NoteInteraction then TB.NoteInteraction() end
                if TB.TryApply then TB.TryApply() end
                TB.Schedule()
            end)
            frame:HookScript("OnHide",function()
                if TB.ClearInteraction then TB.ClearInteraction() end
                TB.Schedule()
            end)
            if hooksecurefunc and type(frame.Refresh)=="function" then
                hooksecurefunc(frame,"Refresh",function() TB.Schedule() end)
            end
        end)
        if ok then TB.boundPanel=native end
    end
    if TB.SyncPoisonDisplay then TB.SyncPoisonDisplay() end
    if not TB.panel:IsShown() then return end
    TB.player=TB.Player()
    TB.snapshot=TB.Snapshot()
    TB.recommendation=TB.Recommend(TB.player,TB.style,TB.snapshot)
    if TB.CheckPending then TB.CheckPending(TB.snapshot,TB.recommendation) end
    TB.Render()
end
function TB.Schedule()
    if queued or not TB.db then return end
    queued=true
    C_Timer.After(.25,function() queued=nil; TB.Refresh() end)
end
function TB.SetStyle(style)
    if TB.InCombat() or not TB.styles[style] then return end
    TB.style=style -- Nur für diese Sitzung; keine Favoriten-/Profilspeicherung.
    TB.status=nil
    TB.Refresh()
    if TB.ApplyMode then TB.ApplyMode(style) end
end

local function Command(input)
    if not TB.Context().inside then TB.Message("Der Berater öffnet sich nur innerhalb einer Tiefe."); return end
    if TB.InCombat() then TB.Message("Bitte das Kampfende abwarten."); return end
    local cmd,value=(input or ""):lower():match("^(%S*)%s*(.-)$")
    local styles={sicher="safe", tempo="fast", entspannt="relaxed"}
    if cmd=="" then
        if not TB.active then TB.SetActive(true) end
        TB.visibility=not TB.panel:IsShown(); TB.Refresh()
    elseif styles[cmd] then TB.SetStyle(styles[cmd])
    elseif cmd=="valeera" then TB.OpenCompanion()
    elseif cmd=="auto" then TB.db.autoShow=not TB.db.autoShow; TB.visibility=nil; TB.Refresh()
    elseif cmd=="unlock" or cmd=="lock" then
        TB.db.unlocked=cmd=="unlock"
        TB.Message(TB.db.unlocked and "Zum Verschieben die Kopfzeile ziehen." or "Position gesperrt.")
    elseif cmd=="reset" then TB.db.position=nil; TB.db.scale=1; TB.Place()
    elseif cmd=="scale" or cmd=="combat" or cmd=="alpha" then
        local number=tonumber(value)
        if not number then TB.Message("Bitte einen Zahlenwert angeben."); return end
        if cmd=="scale" then TB.db.scale=math.max(.7,math.min(1.5,number)); TB.Place()
        elseif cmd=="combat" then TB.db.combatAlpha=math.max(0,math.min(1,number/100))
        else TB.db.alpha=math.max(.2,math.min(1,number/100)) end
        TB.CombatUI()
    else
        TB.Message("/tb · /tb valeera · /tb entspannt|sicher|tempo · /tb auto · /tb unlock|lock · /tb scale 1.1 · /tb combat 12 · /tb alpha 95 · /tb reset")
    end
end

function Buddy.LoadDelves()
    TB.db=Buddy.db.delves; TB.db.tab=nil; TB.style="relaxed"
    for key,value in pairs({autoShow=true,alpha=.96,combatAlpha=.12,scale=1,unlocked=false}) do
        if TB.db[key]==nil then TB.db[key]=value end
    end
    SlashCmdList.TIEFENBEGLEITER=Command
    SLASH_TIEFENBEGLEITER1="/tb"; SLASH_TIEFENBEGLEITER2="/tiefenbegleiter"
    for event in pairs(watch) do pcall(events.RegisterEvent,events,event) end
    TB.Refresh()
end

events:SetScript("OnEvent",function(_,event,arg)
    if not TB.db then return end
    if watch[event] then
        -- Austritt versteckt sofort, auch im Kampf. Ein Nachlauf lässt Eintrittsdaten laden.
        local inside=TB.Context().inside
        if not inside then TB.SetActive(false) end
        if inside and event=="PLAYER_REGEN_ENABLED" and TB.TryApply then TB.TryApply() end
        TB.Schedule(); return
    end
    if not TB.active then return end
    if event=="PLAYER_REGEN_DISABLED" then TB.CombatUI(); return end
    if event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then TB.Place(); return end
    if event=="ADDON_LOADED" and arg~="Blizzard_DelvesCompanionConfiguration" then return end
    if event=="PLAYER_SPECIALIZATION_CHANGED" and arg~="player" then return end
    -- Nur echte Interaktionssignale lösen einen Schreibversuch aus; die
    -- normale Aktualisierung bleibt ausschließlich lesend.
    if event=="TRAIT_SYSTEM_NPC_CLOSED" then
        if TB.ClearInteraction then TB.ClearInteraction() end
        TB.Schedule(); return
    end
    local interacted=false
    if event=="SHOW_DELVES_COMPANION_CONFIGURATION_UI" then
        interacted=TB.NoteInteraction and TB.NoteInteraction() or false
    elseif event=="TRAIT_SYSTEM_INTERACTION_STARTED" then
        -- Payload ist die Traitbaum-ID; nur Begleitertraitbäume zulassen.
        interacted=TB.NoteInteraction and TB.NoteInteraction(arg) or false
    end
    if interacted and TB.TryApply then TB.TryApply() end
    TB.Schedule()
end)
TB.events=events
