-- hubs.lua
local ADDON_NAME = ...
OneWoW.CatalogData:Defer(ADDON_NAME, 'hubs', function()
return {
places={
	["zone:125"]={
		kind="zone",
		name="Dalaran",
		expansion=3,
		expansions={3},
		mapID=571,
		uiMapID=125,
		parentUiMapID=127,
		flags=0,
		order=1,
		instanceType="zone",
		isCity=true,
		achievementIDs={1956},
	},
}
}
end)
