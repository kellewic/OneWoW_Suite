-- mappin.lua
local ADDON_NAME = ...
OneWoW.CatalogData:Defer(ADDON_NAME, 'mappin', function()
return { pins = {} }
end)
