-- hubs.lua
local ADDON_NAME = ...
OneWoW.CatalogData:Defer(ADDON_NAME, 'hubs', function()
return {
places={
	["zone:111"]={
		kind="zone",
		name="Shattrath City",
		expansion=2,
		expansions={2},
		mapID=530,
		uiMapID=111,
		areaID=3703,
		parentUiMapID=101,
		flags=0,
		order=1,
		instanceType="zone",
		isCity=true,
	},
}
}
end)
