local _,B=...
B.Omnium={TREE=1186}
local O=B.Omnium
O.runes={fire=1279599,orbs=1279596,mend=1279603,shell=1279604,lingering=1287663,crit=1287772,haste=1287774,mastery=1287771,versatility=1287770,overload=1279614,residual=1279615,echoes=1289063}
O.labels={fire="Entfesseltes Feuer",orbs="Leerenberührte Kugeln",mend="Selbstheilung",shell="Leerenberührter Schild",lingering="Nachwirkung",crit="Kritische Kraft",haste="Tempo",mastery="Meisterschaft",versatility="Vielseitigkeit",overload="Überladung",residual="Restenergie",echoes="Echos"}
-- Method, 06.11.2026: fünf ursprüngliche Reihen; allgemeine Rollenstandards.
O.profiles={
 TANK={"fire","shell","lingering","versatility","overload"},
 HEALER={"orbs","shell","lingering","haste","overload"},
 DAMAGER={"fire","shell","lingering","crit","overload"},
}
O.roles={"TANK","HEALER","DAMAGER"}
O.roleLabels={TANK="Tank",HEALER="Heiler",DAMAGER="Schaden"}
function O.Preset(spec,class,role)
 local selected=O.db and O.db.role or role
 local src=O.profiles[selected]
 if not src then return nil,"Rolle noch nicht erkannt" end
 local out={};for i,v in ipairs(src) do out[i]=v end
 return out,O.roleLabels[selected].." · allgemeiner Standard"
end
