local _,B=...
local O=B.Omnium
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v) return public(v) and type(v)=="number" end
local function call(owner,key,...)
 local fn=owner and owner[key]
 if type(fn)~="function" then return end
 local ok,value=pcall(fn,...)
 if ok and public(value) then return value end
end
local function text(value)
 if public(value) and type(value)=="string" and value~="" then return value end
end
-- Fremde Blizzard-Fenster nur über pcall und mit IsForbidden-Prüfung lesen.
-- Nicht lesbarer oder geschützter Zustand gilt als geöffnet: die Automatik
-- pausiert dann, statt mitten im Talentfenster zu schreiben.
local function shown(frame)
 if not public(frame) then return true end
 if not frame then return false end
 local ok,value=pcall(function()
  local forbidden=frame:IsForbidden()
  if not public(forbidden) or forbidden then return true end
  return frame:IsShown()
 end)
 return not ok or not public(value) or type(value)~="boolean" or value
end
local function spellName(id,cache)
 if not number(id) or id<=0 then return end
 if cache and cache[id]~=nil then return cache[id] or nil end
 local info=call(C_Spell,"GetSpellInfo",id)
 if not info and C_Spell and C_Spell.RequestLoadSpellData then
  O.waitingSpells=O.waitingSpells or {};O.requestedSpells=O.requestedSpells or {}
  if not O.requestedSpells[id] then
   O.requestedSpells[id]=true;O.waitingSpells[id]=true;pcall(C_Spell.RequestLoadSpellData,id)
  end
 end
 local name=type(info)=="table" and text(info.name) or nil
 if cache then cache[id]=name or false end
 return name
end
function O.Matches(definition,key,cache)
 local expected=O.runes[key]
 if number(definition.spellID) and definition.spellID==expected then return true end
 if number(definition.overriddenSpellID) and definition.overriddenSpellID==expected then return true end
 -- Some Folio definitions use a different spell for the talent than for its
 -- effect. Match exact localized names supplied by the client, never substrings
 -- or node positions. Read() rejects duplicate matches before any write.
 local reference=spellName(expected,cache)
 if not reference then return false end
 return text(definition.overrideName)==reference or spellName(definition.overriddenSpellID,cache)==reference
     or spellName(definition.spellID,cache)==reference
end
local function combat() return InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) end
function O.Player()
 local index=GetSpecialization and GetSpecialization()
 if not number(index) then return end
 local spec,name,_,_,role=GetSpecializationInfo(index)
 local _,class=UnitClass("player")
 -- name ist ein API-String und kann geschützt sein; text() prüft vor der Weitergabe.
 if number(spec) and public(role) and public(class) then return spec,text(name),class,role end
end
function O.Config()
 local id=call(C_Traits,"GetConfigIDByTreeID",O.TREE)
 if not number(id) or id<=0 then return end
 local info=call(C_Traits,"GetConfigInfo",id)
 if type(info)~="table" or not public(info.treeIDs) or type(info.treeIDs)~="table" then return end
 if #info.treeIDs==1 and public(info.treeIDs[1]) and info.treeIDs[1]==O.TREE then return id end
end
function O.Solo()
 local kind
 if IsInInstance then local inside;inside,kind=IsInInstance() end
 return kind~="party" and kind~="raid" and kind~="pvp" and kind~="arena" and not (IsInGroup and IsInGroup())
end
function O.Read()
 if combat() then return {error="Im Kampf pausiert die Erkennung."} end
 local names={}
 local spec,name,class,role=O.Player()
 if not spec then return {error="Spezialisierung lädt noch."} end
 local keys,source=O.Preset(spec,class,role)
 local s={spec=spec,name=name,source=source,rows={},config=O.Config()}
 if not keys then s.error="Für diese Spezialisierung fehlt ein geprüftes Profil.";return s end
 for i,key in ipairs(keys) do s.rows[i]={key=key,name=spellName(O.runes[key],names),status="Rune noch nicht erkannt"} end
 if not s.config then s.error="Omniumfoliant nicht freigeschaltet oder Daten fehlen.";return s end
 local nodes=call(C_Traits,"GetTreeNodes",O.TREE)
 if type(nodes)~="table" then s.error="Runendaten laden noch.";return s end
 for _,nodeID in ipairs(nodes) do
  if number(nodeID) then
   local n=call(C_Traits,"GetNodeInfo",s.config,nodeID)
   if type(n)=="table" and public(n.entryIDs) and type(n.entryIDs)=="table" then
    for _,entryID in ipairs(n.entryIDs) do
     if number(entryID) then
      local e=call(C_Traits,"GetEntryInfo",s.config,entryID)
      local d=type(e)=="table" and number(e.definitionID) and call(C_Traits,"GetDefinitionInfo",e.definitionID)
      if type(d)=="table" then
       for _,row in ipairs(s.rows) do
        if O.Matches(d,row.key,names) then
         if row.node then row.ambiguous=true end
         row.node=nodeID;row.entry=entryID;row.choice=#n.entryIDs>1
         local active=public(n.activeEntry) and n.activeEntry
         row.rank=number(n.activeRank) and n.activeRank or 0
         if type(active)=="table" and number(active.entryID) and row.rank>0 then
          local ae=call(C_Traits,"GetEntryInfo",s.config,active.entryID)
          local ad=type(ae)=="table" and number(ae.definitionID) and call(C_Traits,"GetDefinitionInfo",ae.definitionID)
          if type(ad)=="table" then
           local info=number(ad.spellID) and call(C_Spell,"GetSpellInfo",ad.spellID)
           row.activeName=text(ad.overrideName) or (type(info)=="table" and text(info.name))
           row.activeIcon=number(ad.overrideIcon) and ad.overrideIcon>0 and ad.overrideIcon or (type(info)=="table" and number(info.iconID) and info.iconID)
           row.activeSpell=number(ad.spellID) and ad.spellID or nil
          end
         end
         row.match=type(active)=="table" and number(active.entryID) and active.entryID==entryID and row.rank>0
         row.available=public(n.isAvailable) and n.isAvailable==true and public(n.isVisible) and n.isVisible==true and public(e.isAvailable) and e.isAvailable==true
         row.status=row.match and "Passt" or row.available and "Änderung vorgesehen" or "Noch gesperrt"
        end
       end
      end
     end
    end
   end
  end
 end
 for _,row in ipairs(s.rows) do if row.ambiguous then row.available=false;row.status="Zuordnung unklar" end end
 return s
end
local function status(text) O.status=text;if O.Render then O.Render() end end
local function stop(text) O.pending=nil;O.running=nil;O.requestedRole=nil;status(text) end
function O.Check()
 local tx=O.pending
 if not tx or not tx.committed then return end
 if O.Config()~=tx.config then stop("Konfiguration geändert. Bitte neu prüfen.");return end
 if call(C_Traits,"ConfigHasStagedChanges",tx.config)~=false then return end
 local n=call(C_Traits,"GetNodeInfo",tx.config,tx.node)
 local active=type(n)=="table" and public(n.activeEntry) and n.activeEntry
 if type(active)=="table" and number(active.entryID) and active.entryID==tx.entry and number(n.activeRank) and n.activeRank>0 then
  O.pending=nil
  if O.Player()~=tx.spec then stop("Spezialisierung geändert.");O.Schedule();return end
  C_Timer.After(.3,function() if O.running then O.Step() end end)
 end
end
function O.Step()
 if not O.running or O.pending then return end
 if combat() then stop("Wartet auf das Kampfende.");return end
 -- Eine Benutzerwahl während eines Commits erst nach dessen Bestätigung
 -- übernehmen. Keine zweite Transaktion parallel zum ausstehenden Commit.
 if O.requestedRole then
  O.db.role=O.requestedRole;O.requestedRole=nil;O.running.steps=0
 end
 local s=O.Read()
 if s.error then stop(s.error);return end
 if s.spec~=O.running.spec or O.Solo()~=O.running.solo then stop("Spezialisierung geändert.");O.Schedule();return end
 local id=s.config
 if call(C_Traits,"ConfigHasStagedChanges",id)~=false then stop("Offene manuelle Änderungen zuerst speichern oder verwerfen.");return end
 if call(C_Traits,"CanEditConfig",id)~=true then stop("WoW erlaubt hier noch keine Änderung.");return end
 local chosen
 for _,row in ipairs(s.rows) do
  if not row.match and row.available and not row.ambiguous and (row.rank>0 or call(C_Traits,"CanPurchaseRank",id,row.node,row.entry)==true) then chosen=row;break end
 end
 if not chosen then
  local missing=0;for _,row in ipairs(s.rows) do if not row.match then missing=missing+1 end end
  stop(missing==0 and "Alle fünf Runen passen zum Profil." or "Verfügbare Runen fertig. Nicht erkannt oder gesperrt: "..missing..".");return
 end
 O.running.steps=O.running.steps+1
 if O.running.steps>5 then stop("Auswahl bitte prüfen; keine weiteren automatischen Versuche.");return end
 local tx={config=id,node=chosen.node,entry=chosen.entry,spec=s.spec};O.pending=tx
 local staged=not chosen.choice or call(C_Traits,"SetSelection",id,chosen.node,chosen.entry)==true
 if staged and chosen.rank==0 then
  local n=call(C_Traits,"GetNodeInfo",id,chosen.node)
  if not (type(n)=="table" and number(n.activeRank) and n.activeRank>0) then staged=call(C_Traits,"PurchaseRank",id,chosen.node)==true end
 end
 if not staged or call(C_Traits,"IsReadyForCommit")~=true then
  call(C_Traits,"RollbackConfig",id);stop("Auswahl nicht möglich. Freischaltung/Punkte prüfen.");return
 end
 if call(C_Traits,"CommitConfig",id)~=true then
  call(C_Traits,"RollbackConfig",id);stop("WoW hat das Speichern abgelehnt.");return
 end
 if O.pending~=tx then return end
 tx.committed=true;status("Runenauswahl wird gespeichert …")
 C_Timer.After(.4,O.Check)
 C_Timer.After(8,function() if O.pending==tx then stop("Keine Speicherbestätigung. Bitte den Folianten prüfen.") end end)
end
function O.Apply(manual)
 if O.running or O.pending or (not manual and not O.db.auto) then return end
 if combat() then status("Wartet auf das Kampfende.");return end
 if not manual and shown(GenericTraitFrame) then status("Foliant geöffnet: Automatik pausiert. Bei Bedarf „Jetzt übernehmen“ wählen.");return end
 local spec=O.Player()
 if not spec then status("Spezialisierung lädt noch.");return end
 O.running={spec=spec,solo=O.Solo(),steps=0};O.Step()
end
function O.SelectRole(role)
 if not O.profiles[role] then return false end
 if O.running or O.pending then
  O.requestedRole=role
  return true
 end
 O.db.role=role;O.status=nil;O.Apply(true)
 if O.Render then O.Render() end
 return true
end
function O.Schedule()
 if O.queued then return end
 O.queued=true;C_Timer.After(.5,function() O.queued=false;if O.db.auto then O.Apply(false) elseif O.Render then O.Render() end end)
end
function B.LoadOmnium()
 O.db=B.db.omnium;O.db.stats=nil
 if not O.profiles[O.db.role] then O.db.role=nil end
 if O.db.auto==nil then O.db.auto=true end
 local e=CreateFrame("Frame");O.events=e
 for _,event in ipairs({"GROUP_ROSTER_UPDATE","ZONE_CHANGED_NEW_AREA","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_SPECIALIZATION_CHANGED","PLAYER_REGEN_ENABLED","PLAYER_LEVEL_UP","CURRENCY_DISPLAY_UPDATE","TRAIT_CONFIG_UPDATED","SPELL_DATA_LOAD_RESULT","CONFIG_COMMIT_FAILED"}) do e:RegisterEvent(event) end
 e:SetScript("OnEvent",function(_,event,arg)
  if event=="PLAYER_SPECIALIZATION_CHANGED" and arg~="player" then return end
  if event=="SPELL_DATA_LOAD_RESULT" then
   if O.waitingSpells and O.waitingSpells[arg] then O.waitingSpells[arg]=nil;O.Schedule() end
  elseif event=="CONFIG_COMMIT_FAILED" then
   if O.pending and arg==O.pending.config then stop("Speichern fehlgeschlagen. Bitte Folianten prüfen.") end
  elseif event=="TRAIT_CONFIG_UPDATED" then
   if O.pending and arg==O.pending.config then O.Check() end
   if O.panel and O.panel:IsShown() then O.Render() end
  else O.Schedule() end
 end)
 SLASH_AZEROTHBUDDYOMNIUM1="/abo"
 SlashCmdList.AZEROTHBUDDYOMNIUM=function(input)
  local cmd=(input or ""):lower()
  if cmd=="debug" then
   local state=O.Read()
   B.Message("Omnium: Baum "..O.TREE.." · Konfiguration "..tostring(state.config or "fehlt").." · Spezialisierung "..tostring(state.spec or "fehlt"))
   for _,row in ipairs(state.rows or {}) do B.Message(row.key..": "..row.status.." · Knoten "..tostring(row.node or "?").." · Eintrag "..tostring(row.entry or "?")) end
  elseif cmd=="apply" then O.Apply(true)
  elseif cmd=="auto" then O.db.auto=not O.db.auto;if not O.db.auto then O.running=nil end;status(O.db.auto and "Automatik an." or "Automatik aus.");if O.db.auto then O.Schedule() end
  else O.Toggle() end
 end
end
