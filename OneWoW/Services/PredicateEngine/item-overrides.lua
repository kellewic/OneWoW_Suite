local _, ns = ...

-- Mis-tagged items: Blizzard classID/subClassID wrong; PE reclassifies for
-- #recipe / BuildProps (and IdentityIsRecipeItem).
ns.ItemIDOverrides = {
    -- RECIPE: ALCHEMY
    [275275] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Alchemy },
    [275271] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Alchemy },
    -- RECIPE: BLACKSMITHING
    [265530] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259319] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259317] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259237] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265536] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259322] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259318] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265528] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265534] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259235] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259233] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265532] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259231] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [275306] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [275308] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [275304] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    -- RECIPE: ENCHANTING
    [275314] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Enchanting },
    [275312] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Enchanting },
    [275310] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Enchanting },
    -- RECIPE: ENGINEERING
    [259180] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259174] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259178] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259184] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [268480] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259176] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259172] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259182] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [275320] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [275316] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [275318] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    -- RECIPE: INSCRIPTION
    [259206] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [259210] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [259208] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [257028] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [275324] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [275326] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [275322] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [275328] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    -- RECIPE: JEWELCRAFTING
    [275693] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Jewelcrafting },
    [275695] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Jewelcrafting },
    -- RECIPE: LEATHERWORKING
    [275332] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Leatherworking },
    [275336] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Leatherworking },
    [275334] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Leatherworking },
    [275338] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Leatherworking },
}
