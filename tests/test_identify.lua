local loadfile = dofile("tests/load_locales.lua")
local B={Tiefen={}}
assert(loadfile('Modules/Tiefen/Rules.lua'))('AzerothBuddy',B)
local T=B.Tiefen
local count=0
C_Spell={GetSpellInfo=function(id) count=count+1;return {name='Local '..id} end}
T.Call=function(owner,name,...) return owner[name](...) end
assert(T.Identify({spell=1288795})=='idol' and count==0)
assert(T.Identify({name='Viperwindgötze'})=='idol' and count==0)
assert(T.Identify({name='Local 1288795'})=='idol')
local loaded=count
assert(T.Identify({name='Local 1288795'})=='idol' and count==loaded)
local secret={};function issecretvalue(v) return v==secret end
assert(T.Identify({spell=secret,name=secret})==nil)
print('PASS: indexed curio IDs/aliases, localized cache, secret names')

local choices={role={options={{key='HEALER',entry=1,name='Heiler',available=true}}},
 poison={options={{key='blood',entry=2,name='Blut',available=true}}},
 combat={options={{key='idol',entry=3,name='Idol',available=false}}},
 utility={options={{key='dundun',entry=4,name='Dundun',available=true}}}}
choices.role.current=choices.role.options[1]
local advice=T.Recommend({spec=253,role='DAMAGER'},'relaxed',{slots=choices})
assert(advice.rows[1].match and advice.rows[2].fallback and advice.missing==1 and advice.changes==2)
assert(not T.styles.custom and not T.SaveFavorite,'no favorite mode')
assert(T.Preset({role='TANK'},'safe').role[1]=='HEALER')
assert(T.Preset({role='TANK'},'fast').role[1]=='DAMAGER')
assert(T.Preset({role='HEALER'},'relaxed').role[1]=='TANK')
print('PASS: read-only recommendations, role choices, available fallback and missing options')
