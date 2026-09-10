-- npc_extra.lua
local ADDON_NAME = ...
OneWoW.CatalogData:Defer(ADDON_NAME, 'npc', function()
return {
[76266] = {npcID=76266,expansion=5,roles={"boss"},placeKeys={"instance:476"},encounterIDs={968}},
[77325] = {npcID=77325,name="Blackhand",expansion=5,displayID=53791,roles={"boss"},placeKeys={"instance:457","zone:598"},encounterIDs={959}},
[77927] = {npcID=77927,expansion=5,roles={"rare"},placeKeys={"instance:559"}},
[78564] = {npcID=78564,expansion=5,category="housing",roles={"vendor"},locations={[582]={x=38.5,y=31.4}},placeKeys={"zone:582"}},
[79774] = {npcID=79774,expansion=5,category="housing",roles={"vendor"},locations={[525]={x=44.4,y=47.6}},placeKeys={"zone:525"}},
[79812] = {npcID=79812,expansion=5,category="housing",roles={"vendor"},locations={[525]={x=48.2,y=65.5}},placeKeys={"zone:525"}},
[81133] = {npcID=81133,expansion=5,category="housing",roles={"vendor"},locations={[539]={x=46.2,y=39.3}},placeKeys={"zone:539"}},
[81252] = {npcID=81252,name="Drov the Ruiner",expansion=5,displayID=58260,roles={"rare"},placeKeys={"zone:543"},encounterIDs={1291}},
[83746] = {npcID=83746,expansion=5,roles={"rare"},locations={[542]={x=36,y=39}},placeKeys={"zone:542"},encounterIDs={1262}},
[86532] = {npcID=86532,name="Lanticore Spawnling",expansion=5,displayID=59668,roles={"rare"},placeKeys={"instance:559"}},
[86776] = {npcID=86776,expansion=5,category="housing",roles={"vendor"},locations={[525]={x=52,y=58.6}},placeKeys={"zone:525"}},
[86777] = {npcID=86777,expansion=5,category="housing",roles={"vendor"},locations={[525]={x=59.3,y=24.9}},placeKeys={"zone:525"}},
[86779] = {npcID=86779,expansion=5,category="housing",roles={"vendor"},locations={[525]={x=52,y=58.61}},placeKeys={"zone:525"}},
[87200] = {npcID=87200,expansion=5,category="housing",roles={"vendor"},locations={[582]={x=31,y=15}},placeKeys={"zone:582"}},
[87312] = {npcID=87312,expansion=5,category="housing",roles={"vendor"},locations={[525]={x=48.2,y=66.5}},placeKeys={"zone:525"}},
[88126] = {npcID=88126,expansion=5,category="housing",roles={"vendor"},locations={[582]={x=29.6,y=16.2}},placeKeys={"zone:582"}},
[88220] = {npcID=88220,expansion=5,category="housing",roles={"vendor"},locations={[582]={x=29.6,y=16.21}},placeKeys={"zone:582"}},
[90284] = {npcID=90284,expansion=5,roles={"boss"},placeKeys={"instance:669","zone:661"},encounterIDs={1425}},
[90316] = {npcID=90316,expansion=5,roles={"boss"},placeKeys={"instance:669","zone:661"},encounterIDs={1433}},
[91331] = {npcID=91331,expansion=5,roles={"boss"},placeKeys={"instance:669","zone:661"},encounterIDs={1438}},
[95068] = {npcID=95068,expansion=5,roles={"boss"},placeKeys={"instance:669","zone:661"},encounterIDs={1426}},
}
end)
