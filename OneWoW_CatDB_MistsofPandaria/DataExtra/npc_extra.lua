-- npc_extra.lua
local ADDON_NAME = ...
OneWoW.CatalogData:Defer(ADDON_NAME, 'npc', function()
return {
[59479] = {npcID=59479,expansion=4,roles={"boss"},placeKeys={"instance:302"},encounterIDs={670}},
[62032] = {npcID=62032,name="Lamp Post",expansion=4,displayID=42341,category="housing",roles={"vendor"},locations={[390]={x=62.8,y=23.2}},placeKeys={"zone:390"}},
[62346] = {npcID=62346,expansion=4,roles={"rare"},locations={[376]={x=69.7,y=61.9}},placeKeys={"zone:376"},encounterIDs={725}},
[64632] = {npcID=64632,name="Hopling",expansion=4,displayID=43597,roles={"rare"},placeKeys={"instance:302"}},
[65317] = {npcID=65317,expansion=4,roles={"rare"},placeKeys={"instance:313"}},
[65599] = {npcID=65599,expansion=4,roles={"vendor"},locations={[393]={x=57.04,y=52.37}},placeKeys={"zone:393"}},
[67130] = {npcID=67130,expansion=4,roles={"vendor"},locations={[391]={x=59.04,y=42.26}},placeKeys={"zone:391"}},
[67977] = {npcID=67977,expansion=4,roles={"boss"},placeKeys={"instance:362"},encounterIDs={825}},
[68036] = {npcID=68036,expansion=4,roles={"boss"},placeKeys={"instance:362"},encounterIDs={818}},
[68397] = {npcID=68397,expansion=4,roles={"boss"},placeKeys={"instance:362"},encounterIDs={832}},
[69017] = {npcID=69017,expansion=4,roles={"boss"},placeKeys={"instance:362"},encounterIDs={820}},
[69099] = {npcID=69099,expansion=4,roles={"rare"},locations={[504]={x=60.5,y=37.3}},placeKeys={"zone:504"},encounterIDs={814}},
[69465] = {npcID=69465,expansion=4,roles={"boss"},placeKeys={"instance:362"},encounterIDs={827}},
[69712] = {npcID=69712,expansion=4,roles={"boss"},placeKeys={"instance:362"},encounterIDs={828}},
[69748] = {npcID=69748,name="Living Sandling",expansion=4,displayID=47252,roles={"rare"},placeKeys={"instance:362"}},
[71466] = {npcID=71466,expansion=4,roles={"boss"},placeKeys={"instance:369","zone:556"},encounterIDs={864}},
[72157] = {npcID=72157,name="Hagrus",expansion=4,roles={"rare"},locations={[3]={x=47,y=55.06}},placeKeys={"instance:369","zone:556"}},
[73715] = {npcID=73715,name="Rivett Clutchpop",expansion=4,roles={"vendor"},locations={[563]={x=48.7,y=28.12}},placeKeys={"zone:563"}},
}
end)
