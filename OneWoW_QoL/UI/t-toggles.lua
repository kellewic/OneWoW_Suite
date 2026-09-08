local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local CATEGORY_ORDER = {
    "GAMEPLAY", "INTERFACE", "NAMEPLATES", "COMBAT_TEXT",
    "CAMERA", "CHAT", "AUDIO", "GRAPHICS", "NETWORK",
}

-- Favorites were keyed by cvar name; migrate old → new after Retail 12.0 renames.
local CVAR_FAV_RENAMES = {
    autointeract = "autoInteract",
    nameplateShowFriends = "nameplateShowFriendlyPlayers",
    ShowClassColorInNameplate = "nameplateShowClassColor",
    ShowClassColorInFriendlyNameplate = "nameplateShowFriendlyClassColor",
    floatingCombatTextCombatDamage = "floatingCombatTextCombatDamage_v2",
    floatingCombatTextCombatHealing = "floatingCombatTextCombatHealing_v2",
    floatingCombatTextCombatState = "floatingCombatTextCombatState_v2",
    floatingCombatTextAuras = "floatingCombatTextAuras_v2",
    floatingCombatTextDodgeParryMiss = "floatingCombatTextDodgeParryMiss_v2",
    floatingCombatTextHonorGains = "floatingCombatTextHonorGains_v2",
    floatingCombatTextRepChanges = "floatingCombatTextRepChanges_v2",
    floatingCombatTextEnergyGains = "floatingCombatTextEnergyGains_v2",
    floatingCombatTextComboPoints = "floatingCombatTextComboPoints_v2",
    floatingCombatTextReactives = "floatingCombatTextReactives_v2",
    floatingCombatTextPetMeleeDamage = "floatingCombatTextPetMeleeDamage_v2",
    cameraDynamicPitch = "test_cameraDynamicPitch",
    gxVSync = "vsync",
    gxMaxFrameLatency = "GxMaxFrameLatency",
    particleDensity = "graphicsParticleDensity",
}

local CVAR_DATA = {
    -- GAMEPLAY
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoLootDefault",              nameGlobal = "AUTO_LOOT_DEFAULT_TEXT",            desc = "TOGGLE_DESC_autoLootDefault" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoSelfCast",                 nameGlobal = "AUTO_SELF_CAST_TEXT",               desc = "TOGGLE_DESC_autoSelfCast" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoDismount",                 name = "TOGGLE_NAME_autoDismount",                desc = "TOGGLE_DESC_autoDismount" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoDismountFlying",           nameGlobal = "AUTO_DISMOUNT_FLYING_TEXT",         desc = "TOGGLE_DESC_autoDismountFlying" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoStand",                    name = "TOGGLE_NAME_autoStand",                   desc = "TOGGLE_DESC_autoStand" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoUnshift",                  name = "TOGGLE_NAME_autoUnshift",                 desc = "TOGGLE_DESC_autoUnshift" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "assistAttack",                 name = "TOGGLE_NAME_assistAttack",                desc = "TOGGLE_DESC_assistAttack" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "ActionButtonUseKeyDown",       name = "TOGGLE_NAME_ActionButtonUseKeyDown",      desc = "TOGGLE_DESC_ActionButtonUseKeyDown" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "ActionButtonUseKeyHeldSpell",  nameGlobal = "PRESS_AND_HOLD_CASTING_OPTION",     desc = "TOGGLE_DESC_ActionButtonUseKeyHeldSpell" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "enableMouseoverCast",          nameGlobal = "ENABLE_MOUSEOVER_CAST",             desc = "TOGGLE_DESC_enableMouseoverCast" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "deselectOnClick",              name = "TOGGLE_NAME_deselectOnClick",             desc = "TOGGLE_DESC_deselectOnClick" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "stopAutoAttackOnTargetChange", name = "TOGGLE_NAME_stopAutoAttackOnTargetChange", desc = "TOGGLE_DESC_stopAutoAttackOnTargetChange" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "lootUnderMouse",               nameGlobal = "LOOT_UNDER_MOUSE_TEXT",             desc = "TOGGLE_DESC_lootUnderMouse" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "interactOnLeftClick",          nameGlobal = "INTERACT_ON_LEFT_CLICK_TEXT",       desc = "TOGGLE_DESC_interactOnLeftClick" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoInteract",                 nameGlobal = "CLICK_TO_MOVE",                     desc = "TOGGLE_DESC_autointeract" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoClearAFK",                 nameGlobal = "CLEAR_AFK",                         desc = "TOGGLE_DESC_autoClearAFK" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "secureAbilityToggle",          name = "TOGGLE_NAME_secureAbilityToggle",         desc = "TOGGLE_DESC_secureAbilityToggle" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "combinedBags",                 nameGlobal = "USE_COMBINED_BAGS_TEXT",            desc = "TOGGLE_DESC_combinedBags" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "arachnophobiaMode",            nameGlobal = "ARACHNOPHOBIA_MODE_CHECKBOX",       desc = "TOGGLE_DESC_arachnophobiaMode" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "assistedCombatHighlight",      nameGlobal = "ASSISTED_COMBAT_HIGHLIGHT_LABEL",   desc = "TOGGLE_DESC_assistedCombatHighlight" },

    -- INTERFACE
    { cat = "INTERFACE", widget = "checkbox", cvar = "countdownForCooldowns",               nameGlobal = "COUNTDOWN_FOR_COOLDOWNS_TEXT", desc = "TOGGLE_DESC_countdownForCooldowns" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "displaySpellActivationOverlays",      name = "TOGGLE_NAME_displaySpellActivationOverlays", desc = "TOGGLE_DESC_displaySpellActivationOverlays" },
    { cat = "INTERFACE", widget = "slider",   cvar = "spellActivationOverlayOpacity",       nameGlobal = "SPELL_ALERT_OPACITY", desc = "TOGGLE_DESC_spellActivationOverlayOpacity", min = 0, max = 1, step = 0.05 },
    { cat = "INTERFACE", widget = "checkbox", cvar = "lockActionBars",                      nameGlobal = "LOCK_ACTIONBAR_TEXT", desc = "TOGGLE_DESC_lockActionBars" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "buffDurations",                       nameGlobal = "SHOW_BUFF_DURATION_TEXT", desc = "TOGGLE_DESC_buffDurations" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "showTargetOfTarget",                  nameGlobal = "SHOW_TARGET_OF_TARGET_TEXT", desc = "TOGGLE_DESC_showTargetOfTarget" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "showTargetCastbar",                   name = "TOGGLE_NAME_showTargetCastbar", desc = "TOGGLE_DESC_showTargetCastbar" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "breakUpLargeNumbers",                 name = "TOGGLE_NAME_breakUpLargeNumbers", desc = "TOGGLE_DESC_breakUpLargeNumbers" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "alwaysCompareItems",                  name = "TOGGLE_NAME_alwaysCompareItems", desc = "TOGGLE_DESC_alwaysCompareItems" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "missingTransmogSourceInItemTooltips", name = "TOGGLE_NAME_missingTransmogSourceInItemTooltips", desc = "TOGGLE_DESC_missingTransmogSourceInItemTooltips" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "autoQuestWatch",                      name = "TOGGLE_NAME_autoQuestWatch", desc = "TOGGLE_DESC_autoQuestWatch" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "mapFade",                             nameGlobal = "MAP_FADE_TEXT", desc = "TOGGLE_DESC_mapFade" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "rotateMinimap",                       nameGlobal = "ROTATE_MINIMAP", desc = "TOGGLE_DESC_rotateMinimap" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "useUiScale",                          nameGlobal = "USE_UISCALE", desc = "TOGGLE_DESC_useUiScale" },
    { cat = "INTERFACE", widget = "slider",   cvar = "uiScale",                             nameGlobal = "UI_SCALE", desc = "TOGGLE_DESC_uiScale", min = 0.65, max = 1.15, step = 0.01 },
    { cat = "INTERFACE", widget = "checkbox", cvar = "noBuffDebuffFilterOnTarget",          name = "TOGGLE_NAME_noBuffDebuffFilterOnTarget", desc = "TOGGLE_DESC_noBuffDebuffFilterOnTarget" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "scriptErrors",                        name = "TOGGLE_NAME_scriptErrors", desc = "TOGGLE_DESC_scriptErrors" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "occludedSilhouettePlayer",            nameGlobal = "SHOW_SILHOUETTE_OPTION", desc = "TOGGLE_DESC_occludedSilhouettePlayer" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "lossOfControl",                       nameGlobal = "LOSS_OF_CONTROL", desc = "TOGGLE_DESC_lossOfControl" },

    -- NAMEPLATES
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowAll",                              nameGlobal = "UNIT_NAMEPLATES_AUTOMODE", desc = "TOGGLE_DESC_nameplateShowAll" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowEnemies",                          nameGlobal = "UNIT_NAMEPLATES_SHOW_ENEMIES", desc = "TOGGLE_DESC_nameplateShowEnemies" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowEnemyMinions",                    name = "TOGGLE_NAME_nameplateShowEnemyMinions", desc = "TOGGLE_DESC_nameplateShowEnemyMinions" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowEnemyMinus",                      name = "TOGGLE_NAME_nameplateShowEnemyMinus", desc = "TOGGLE_DESC_nameplateShowEnemyMinus" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowFriendlyPlayers",                 nameGlobal = "UNIT_NAMEPLATES_SHOW_FRIENDS", desc = "TOGGLE_DESC_nameplateShowFriends" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowFriendlyPlayerMinions",           name = "TOGGLE_NAME_nameplateShowFriendlyPlayerMinions", desc = "TOGGLE_DESC_nameplateShowFriendlyPlayerMinions" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowFriendlyNpcs",                    nameGlobal = "UNIT_NAMEPLATES_SHOW_FRIENDLY_NPCS", desc = "TOGGLE_DESC_nameplateShowFriendlyNpcs" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowOnlyNameForFriendlyPlayerUnits",  name = "TOGGLE_NAME_nameplateShowOnlyNameForFriendlyPlayerUnits", desc = "TOGGLE_DESC_nameplateShowOnlyNameForFriendlyPlayerUnits" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateUseClassColorForFriendlyPlayerUnitNames", name = "TOGGLE_NAME_nameplateUseClassColorForFriendlyPlayerUnitNames", desc = "TOGGLE_DESC_nameplateUseClassColorForFriendlyPlayerUnitNames" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowFriendlyRealmName",               name = "TOGGLE_NAME_nameplateShowFriendlyRealmName", desc = "TOGGLE_DESC_nameplateShowFriendlyRealmName" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowOffscreen",                       nameGlobal = "UNIT_NAMEPLATES_SHOW_OFFSCREEN", desc = "TOGGLE_DESC_nameplateShowOffscreen" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowSelf",                            nameGlobal = "DISPLAY_PERSONAL_RESOURCE", desc = "TOGGLE_DESC_nameplateShowSelf" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowClassColor",                      name = "TOGGLE_NAME_ShowClassColorInNameplate", desc = "TOGGLE_DESC_ShowClassColorInNameplate" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowFriendlyClassColor",              name = "TOGGLE_NAME_ShowClassColorInFriendlyNameplate", desc = "TOGGLE_DESC_ShowClassColorInFriendlyNameplate" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateOtherAtBase",                         name = "TOGGLE_NAME_nameplateOtherAtBase", desc = "TOGGLE_DESC_nameplateOtherAtBase" },
    { cat = "NAMEPLATES", widget = "slider",   cvar = "nameplateMaxDistance",                         name = "TOGGLE_NAME_nameplateMaxDistance", desc = "TOGGLE_DESC_nameplateMaxDistance", min = 10, max = 60, step = 1 },

    -- COMBAT_TEXT
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "enableFloatingCombatText",                      nameGlobal = "SHOW_COMBAT_TEXT_TEXT",                      desc = "TOGGLE_DESC_enableFloatingCombatText" },
    { cat = "COMBAT_TEXT", widget = "slider",   cvar = "WorldTextScale_v2",                             name = "TOGGLE_NAME_WorldTextScale_v2",                             desc = "TOGGLE_DESC_WorldTextScale_v2", min = 0.5, max = 2.5, step = 0.1 },
    { cat = "COMBAT_TEXT", widget = "dropdown", cvar = "floatingCombatTextFloatMode_v2",
        name = "TOGGLE_NAME_floatingCombatTextFloatMode_v2", desc = "TOGGLE_DESC_floatingCombatTextFloatMode_v2",
        options   = { "1", "2", "3" },
        optLabels = { "TOGGLE_OPT_floatingCombatTextFloatMode_1", "TOGGLE_OPT_floatingCombatTextFloatMode_2", "TOGGLE_OPT_floatingCombatTextFloatMode_3" } },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatDamage_v2",              name = "TOGGLE_NAME_floatingCombatTextCombatDamage",                desc = "TOGGLE_DESC_floatingCombatTextCombatDamage" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatLogPeriodicSpells_v2",   name = "TOGGLE_NAME_floatingCombatTextCombatLogPeriodicSpells_v2",  desc = "TOGGLE_DESC_floatingCombatTextCombatLogPeriodicSpells_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatHealing_v2",             name = "TOGGLE_NAME_floatingCombatTextCombatHealing",               desc = "TOGGLE_DESC_floatingCombatTextCombatHealing" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatHealingAbsorbTarget_v2", name = "TOGGLE_NAME_floatingCombatTextCombatHealingAbsorbTarget_v2", desc = "TOGGLE_DESC_floatingCombatTextCombatHealingAbsorbTarget_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatDamageDirectionalScale_v2", name = "TOGGLE_NAME_floatingCombatTextCombatDamageDirectionalScale_v2", desc = "TOGGLE_DESC_floatingCombatTextCombatDamageDirectionalScale_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatState_v2",               name = "TOGGLE_NAME_floatingCombatTextCombatState",                 desc = "TOGGLE_DESC_floatingCombatTextCombatState" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextAuras_v2",                     name = "TOGGLE_NAME_floatingCombatTextAuras",                       desc = "TOGGLE_DESC_floatingCombatTextAuras" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextDodgeParryMiss_v2",            name = "TOGGLE_NAME_floatingCombatTextDodgeParryMiss",              desc = "TOGGLE_DESC_floatingCombatTextDodgeParryMiss" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextDamageReduction_v2",           name = "TOGGLE_NAME_floatingCombatTextDamageReduction_v2",          desc = "TOGGLE_DESC_floatingCombatTextDamageReduction_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextHonorGains_v2",                name = "TOGGLE_NAME_floatingCombatTextHonorGains",                  desc = "TOGGLE_DESC_floatingCombatTextHonorGains" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextRepChanges_v2",                name = "TOGGLE_NAME_floatingCombatTextRepChanges",                  desc = "TOGGLE_DESC_floatingCombatTextRepChanges" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextEnergyGains_v2",               name = "TOGGLE_NAME_floatingCombatTextEnergyGains",                 desc = "TOGGLE_DESC_floatingCombatTextEnergyGains" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextPeriodicEnergyGains_v2",       name = "TOGGLE_NAME_floatingCombatTextPeriodicEnergyGains_v2",      desc = "TOGGLE_DESC_floatingCombatTextPeriodicEnergyGains_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextComboPoints_v2",               name = "TOGGLE_NAME_floatingCombatTextComboPoints",                 desc = "TOGGLE_DESC_floatingCombatTextComboPoints" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextReactives_v2",                 name = "TOGGLE_NAME_floatingCombatTextReactives",                   desc = "TOGGLE_DESC_floatingCombatTextReactives" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextLowManaHealth_v2",             name = "TOGGLE_NAME_floatingCombatTextLowManaHealth_v2",            desc = "TOGGLE_DESC_floatingCombatTextLowManaHealth_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatHealingAbsorbSelf_v2",   name = "TOGGLE_NAME_floatingCombatTextCombatHealingAbsorbSelf_v2",  desc = "TOGGLE_DESC_floatingCombatTextCombatHealingAbsorbSelf_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextFriendlyHealers_v2",           name = "TOGGLE_NAME_floatingCombatTextFriendlyHealers_v2",          desc = "TOGGLE_DESC_floatingCombatTextFriendlyHealers_v2" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextPetMeleeDamage_v2",            name = "TOGGLE_NAME_floatingCombatTextPetMeleeDamage",              desc = "TOGGLE_DESC_floatingCombatTextPetMeleeDamage" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextPetSpellDamage_v2",            name = "TOGGLE_NAME_floatingCombatTextPetSpellDamage_v2",           desc = "TOGGLE_DESC_floatingCombatTextPetSpellDamage_v2" },

    -- CAMERA
    { cat = "CAMERA", widget = "checkbox", cvar = "cameraBobbing",              name = "TOGGLE_NAME_cameraBobbing",              desc = "TOGGLE_DESC_cameraBobbing" },
    { cat = "CAMERA", widget = "checkbox", cvar = "cameraWaterCollision",       name = "TOGGLE_NAME_cameraWaterCollision",       desc = "TOGGLE_DESC_cameraWaterCollision" },
    { cat = "CAMERA", widget = "checkbox", cvar = "flightAngleLookAhead",       name = "TOGGLE_NAME_flightAngleLookAhead",       desc = "TOGGLE_DESC_flightAngleLookAhead" },
    { cat = "CAMERA", widget = "checkbox", cvar = "test_cameraDynamicPitch",    name = "TOGGLE_NAME_cameraDynamicPitch",         desc = "TOGGLE_DESC_cameraDynamicPitch" },
    { cat = "CAMERA", widget = "checkbox", cvar = "cameraIndirectVisibility",   name = "TOGGLE_NAME_cameraIndirectVisibility",   desc = "TOGGLE_DESC_cameraIndirectVisibility" },
    { cat = "CAMERA", widget = "slider", cvar = "cameraIndirectOffset",         name = "TOGGLE_NAME_cameraIndirectOffset",       desc = "TOGGLE_DESC_cameraIndirectOffset",       min = 1.0, max = 10.0, step = 0.1 },
    { cat = "CAMERA", widget = "slider", cvar = "cameraDistanceMaxZoomFactor", name = "TOGGLE_NAME_cameraDistanceMaxZoomFactor", desc = "TOGGLE_DESC_cameraDistanceMaxZoomFactor", min = 1.0, max = 2.6, step = 0.1 },
    { cat = "CAMERA", widget = "slider", cvar = "cameraYawMoveSpeed",          name = "TOGGLE_NAME_cameraYawMoveSpeed",          desc = "TOGGLE_DESC_cameraYawMoveSpeed",          min = 90,  max = 270, step = 5 },
    { cat = "CAMERA", widget = "slider", cvar = "cameraPitchMoveSpeed",        name = "TOGGLE_NAME_cameraPitchMoveSpeed",        desc = "TOGGLE_DESC_cameraPitchMoveSpeed",        min = 45,  max = 135, step = 5 },
    { cat = "CAMERA", widget = "slider", cvar = "cameraZoomSpeed",             name = "TOGGLE_NAME_cameraZoomSpeed",             desc = "TOGGLE_DESC_cameraZoomSpeed",             min = 1,   max = 50,  step = 1 },

    -- CHAT
    { cat = "CHAT", widget = "checkbox", cvar = "chatBubbles",           nameGlobal = "CHAT_BUBBLES_TEXT", desc = "TOGGLE_DESC_chatBubbles" },
    { cat = "CHAT", widget = "checkbox", cvar = "chatBubblesParty",      nameGlobal = "PARTY_CHAT_BUBBLES_TEXT", desc = "TOGGLE_DESC_chatBubblesParty" },
    { cat = "CHAT", widget = "checkbox", cvar = "chatBubblesRaid",       nameGlobal = "RAID_CHAT_BUBBLES_TEXT", desc = "TOGGLE_DESC_chatBubblesRaid" },
    { cat = "CHAT", widget = "checkbox", cvar = "colorChatNamesByClass", name = "TOGGLE_NAME_colorChatNamesByClass", desc = "TOGGLE_DESC_colorChatNamesByClass" },
    { cat = "CHAT", widget = "checkbox", cvar = "blockTrades",           nameGlobal = "BLOCK_TRADES", desc = "TOGGLE_DESC_blockTrades" },
    { cat = "CHAT", widget = "checkbox", cvar = "blockChannelInvites",   nameGlobal = "BLOCK_CHAT_CHANNEL_INVITE", desc = "TOGGLE_DESC_blockChannelInvites" },
    { cat = "CHAT", widget = "checkbox", cvar = "guildMemberNotify",     nameGlobal = "GUILDMEMBER_ALERT", desc = "TOGGLE_DESC_guildMemberNotify" },
    { cat = "CHAT", widget = "checkbox", cvar = "chatMouseScroll",       nameGlobal = "CHAT_MOUSE_WHEEL_SCROLL", desc = "TOGGLE_DESC_chatMouseScroll" },
    { cat = "CHAT", widget = "checkbox", cvar = "profanityFilter",       nameGlobal = "PROFANITY_FILTER", desc = "TOGGLE_DESC_profanityFilter" },
    { cat = "CHAT", widget = "dropdown", cvar = "chatStyle",
        name = "TOGGLE_NAME_chatStyle", desc = "TOGGLE_DESC_chatStyle",
        options   = { "classic", "im" },
        optGlobals = { "CLASSIC_STYLE", "IM_STYLE" } },

    -- AUDIO
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableAllSound",  nameGlobal = "ENABLE_SOUND", desc = "TOGGLE_DESC_Sound_EnableAllSound" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableMusic",     nameGlobal = "ENABLE_MUSIC", desc = "TOGGLE_DESC_Sound_EnableMusic" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableSFX",       nameGlobal = "ENABLE_SOUNDFX", desc = "TOGGLE_DESC_Sound_EnableSFX" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableDialog",    nameGlobal = "ENABLE_DIALOG", desc = "TOGGLE_DESC_Sound_EnableDialog" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableAmbience",  nameGlobal = "ENABLE_AMBIENCE", desc = "TOGGLE_DESC_Sound_EnableAmbience" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnablePetSounds", nameGlobal = "ENABLE_PET_SOUNDS", desc = "TOGGLE_DESC_Sound_EnablePetSounds" },
    { cat = "AUDIO", widget = "checkbox", cvar = "FootstepSounds",        name = "TOGGLE_NAME_FootstepSounds", desc = "TOGGLE_DESC_FootstepSounds" },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_MasterVolume", nameGlobal = "MASTER_VOLUME", desc = "TOGGLE_DESC_Sound_MasterVolume", min = 0.0, max = 1.0, step = 0.05 },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_MusicVolume",  name = "TOGGLE_NAME_Sound_MusicVolume",  desc = "TOGGLE_DESC_Sound_MusicVolume",  min = 0.0, max = 1.0, step = 0.05 },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_SFXVolume",    name = "TOGGLE_NAME_Sound_SFXVolume",    desc = "TOGGLE_DESC_Sound_SFXVolume",    min = 0.0, max = 1.0, step = 0.05 },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_AmbienceVolume", name = "TOGGLE_NAME_Sound_AmbienceVolume", desc = "TOGGLE_DESC_Sound_AmbienceVolume", min = 0.0, max = 1.0, step = 0.05 },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_DialogVolume", name = "TOGGLE_NAME_Sound_DialogVolume", desc = "TOGGLE_DESC_Sound_DialogVolume", min = 0.0, max = 1.0, step = 0.05 },

    -- GRAPHICS
    { cat = "GRAPHICS", widget = "checkbox", cvar = "ffxDeath",                    name = "TOGGLE_NAME_ffxDeath",                    desc = "TOGGLE_DESC_ffxDeath" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "ffxGlow",                     name = "TOGGLE_NAME_ffxGlow",                     desc = "TOGGLE_DESC_ffxGlow" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "ffxNether",                   name = "TOGGLE_NAME_ffxNether",                   desc = "TOGGLE_DESC_ffxNether" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "emphasizeMySpellEffects",     name = "TOGGLE_NAME_emphasizeMySpellEffects",     desc = "TOGGLE_DESC_emphasizeMySpellEffects" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "doNotFlashLowHealthWarning",  nameGlobal = "FLASH_LOW_HEALTH_WARNING", desc = "TOGGLE_DESC_doNotFlashLowHealthWarning" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "findYourselfAnywhere",        nameGlobal = "SELF_HIGHLIGHT_OPTION", desc = "TOGGLE_DESC_findYourselfAnywhere" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "findYourselfModeCircle",      name = "TOGGLE_NAME_findYourselfModeCircle", desc = "TOGGLE_DESC_findYourselfModeCircle" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "findYourselfModeOutline",     name = "TOGGLE_NAME_findYourselfModeOutline", desc = "TOGGLE_DESC_findYourselfModeOutline" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "findYourselfModeIcon",        name = "TOGGLE_NAME_findYourselfModeIcon", desc = "TOGGLE_DESC_findYourselfModeIcon" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "vsync",                       nameGlobal = "VERTICAL_SYNC", desc = "TOGGLE_DESC_gxVSync" },
    { cat = "GRAPHICS", widget = "dropdown", cvar = "graphicsParticleDensity",
        nameGlobal = "PARTICLE_DENSITY", desc = "TOGGLE_DESC_graphicsParticleDensity",
        options    = { "0", "1", "2", "3", "4", "5" },
        optGlobals = { "VIDEO_OPTIONS_DISABLED", "VIDEO_OPTIONS_LOW", "VIDEO_OPTIONS_FAIR", "VIDEO_OPTIONS_MEDIUM", "VIDEO_OPTIONS_HIGH", "VIDEO_OPTIONS_ULTRA" } },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "useMaxFPS",          name = "TOGGLE_NAME_useMaxFPS", desc = "TOGGLE_DESC_useMaxFPS" },
    { cat = "GRAPHICS", widget = "slider",   cvar = "maxFPS",             nameGlobal = "MAXFPS", desc = "TOGGLE_DESC_maxFPS", min = 8, max = 200, step = 1 },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "useMaxFPSBk",        name = "TOGGLE_NAME_useMaxFPSBk", desc = "TOGGLE_DESC_useMaxFPSBk" },
    { cat = "GRAPHICS", widget = "slider",   cvar = "maxFPSBk",           nameGlobal = "MAXFPSBK", desc = "TOGGLE_DESC_maxFPSBk", min = 8, max = 200, step = 1 },
    { cat = "GRAPHICS", widget = "slider",   cvar = "GxMaxFrameLatency",  name = "TOGGLE_NAME_gxMaxFrameLatency", desc = "TOGGLE_DESC_gxMaxFrameLatency", min = 1, max = 6, step = 1 },
    { cat = "GRAPHICS", widget = "slider",   cvar = "RenderScale",        nameGlobal = "RENDER_SCALE", desc = "TOGGLE_DESC_RenderScale", min = 0.5, max = 2.0, step = 0.05 },
    { cat = "GRAPHICS", widget = "dropdown", cvar = "graphicsQuality",
        nameGlobal = "GRAPHICS_QUALITY", desc = "TOGGLE_DESC_graphicsQuality",
        options   = { "1","2","3","4","5","6","7","8","9","10" },
        optLabels = { "TOGGLE_OPT_graphicsQuality_1","TOGGLE_OPT_graphicsQuality_2","TOGGLE_OPT_graphicsQuality_3","TOGGLE_OPT_graphicsQuality_4","TOGGLE_OPT_graphicsQuality_5","TOGGLE_OPT_graphicsQuality_6","TOGGLE_OPT_graphicsQuality_7","TOGGLE_OPT_graphicsQuality_8","TOGGLE_OPT_graphicsQuality_9","TOGGLE_OPT_graphicsQuality_10" } },
    { cat = "GRAPHICS", widget = "dropdown", cvar = "ffxAntiAliasingMode",
        nameGlobal = "ANTIALIASING", desc = "TOGGLE_DESC_ffxAntiAliasingMode",
        options    = { "0","1","2","3","4" },
        optGlobals = { "VIDEO_OPTIONS_NONE", "ANTIALIASING_FXAA_LOW", "ANTIALIASING_FXAA_HIGH", "ANTIALIASING_CMAA", "ANTIALIASING_CMAA2" } },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "colorblindMode",           nameGlobal = "USE_COLORBLIND_MODE", desc = "TOGGLE_DESC_colorblindMode" },
    { cat = "GRAPHICS", widget = "dropdown", cvar = "colorblindSimulator",
        nameGlobal = "COLORBLIND_FILTER", desc = "TOGGLE_DESC_colorblindSimulator",
        options    = { "0","1","2","3" },
        optGlobals = { "COLORBLIND_OPTION_NONE", "COLORBLIND_OPTION_PROTANOPIA", "COLORBLIND_OPTION_DEUTERANOPIA", "COLORBLIND_OPTION_TRITANOPIA" } },
    { cat = "GRAPHICS", widget = "slider",   cvar = "colorblindWeaknessFactor", name = "TOGGLE_NAME_colorblindWeaknessFactor", desc = "TOGGLE_DESC_colorblindWeaknessFactor", min = 0, max = 1, step = 0.05 },

    -- NETWORK
    { cat = "NETWORK", widget = "checkbox", cvar = "disableServerNagle",  name = "TOGGLE_NAME_disableServerNagle",  desc = "TOGGLE_DESC_disableServerNagle" },
    { cat = "NETWORK", widget = "slider", cvar = "SpellQueueWindow", name = "TOGGLE_NAME_SpellQueueWindow", desc = "TOGGLE_DESC_SpellQueueWindow", min = 0, max = 400, step = 10 },
}

ns.GetCVarList = function() return CVAR_DATA end

for i = 1, #CVAR_DATA do
    OneWoW.SearchRegistry:RegisterCVarRow(CVAR_DATA[i])
end

local selectedRow = nil
local favMigrationDone = false

local function QoLToggleFavStore()
    local db = ns.db.global
    db.uiFavorites = db.uiFavorites or { features = {}, toggles = {} }
    db.uiFavorites.toggles = db.uiFavorites.toggles or {}
    return db.uiFavorites
end

local function MigrateToggleFavorites()
    if favMigrationDone then return end
    favMigrationDone = true
    local u = QoLToggleFavStore()
    local toggles = u.toggles
    for oldKey, newKey in pairs(CVAR_FAV_RENAMES) do
        if toggles[oldKey] then
            toggles[newKey] = true
            toggles[oldKey] = nil
        end
    end
end

local function ToggleFavKey(entry)
    if not entry then return "" end
    return entry.cvar or entry.name or ""
end

local function IsQoLToggleFavorite(entry)
    MigrateToggleFavorites()
    local u = QoLToggleFavStore()
    return u and entry and u.toggles[ToggleFavKey(entry)] == true
end

local function SetQoLToggleFavorite(entry, on)
    MigrateToggleFavorites()
    local u = QoLToggleFavStore()
    if u and entry then
        u.toggles[ToggleFavKey(entry)] = on and true or nil
    end
end

local function FormatSliderVal(value, step)
    if not step or step >= 1 then
        return tostring(math.floor(value + 0.5))
    elseif step >= 0.01 then
        return string.format("%.2f", value)
    else
        return string.format("%.3f", value)
    end
end

local function ToggleName(entry)
    if entry.nameGlobal then
        return _G[entry.nameGlobal] or entry.nameGlobal
    end
    return L[entry.name]
end

local function ToggleDesc(entry)
    return L[entry.desc]
end

local function ToggleOptLabel(entry, i)
    if entry.optGlobals and entry.optGlobals[i] then
        return _G[entry.optGlobals[i]] or entry.optGlobals[i]
    end
    return L[entry.optLabels[i]]
end

--- Match display name or cvar (so "floating" finds floatingCombatText* rows).
local function ToggleMatchesFilter(entry, filter)
    if not filter then return true end
    if ToggleName(entry):lower():find(filter, 1, true) then return true end
    if entry.cvar and entry.cvar:lower():find(filter, 1, true) then return true end
    return false
end

--- FCT *_v2 / WorldTextScale need a refresh flicker to apply (same as AIO).
local function NeedsFCTRefresh(cvar)
    return cvar == "WorldTextScale_v2"
        or (type(cvar) == "string" and cvar:find("^floatingCombatText", 1, true) == 1)
end

local SELF_HIGHLIGHT_MODES = {
    findYourselfModeCircle = true,
    findYourselfModeOutline = true,
    findYourselfModeIcon = true,
}

local function SetToggleCVar(cvar, value)
    C_CVar.SetCVar(cvar, value)
    if cvar == "spellActivationOverlayOpacity" then
        local num = tonumber(value) or 0
        C_CVar.SetCVar("displaySpellActivationOverlays", num > 0 and "1" or "0")
    elseif cvar == "maxFPS" then
        C_CVar.SetCVar("useMaxFPS", "1")
    elseif cvar == "maxFPSBk" then
        C_CVar.SetCVar("useMaxFPSBk", "1")
    elseif SELF_HIGHLIGHT_MODES[cvar] then
        local any = C_CVar.GetCVarBool("findYourselfModeCircle")
            or C_CVar.GetCVarBool("findYourselfModeOutline")
            or C_CVar.GetCVarBool("findYourselfModeIcon")
        C_CVar.SetCVar("findYourselfAnywhere", any and "1" or "0")
    elseif cvar == "findYourselfAnywhere" and value == "1" then
        if not C_CVar.GetCVarBool("findYourselfModeCircle")
            and not C_CVar.GetCVarBool("findYourselfModeOutline")
            and not C_CVar.GetCVarBool("findYourselfModeIcon") then
            C_CVar.SetCVar("findYourselfModeCircle", "1")
        end
    end
    if NeedsFCTRefresh(cvar) and C_CVar.GetCVarBool("enableFloatingCombatText") then
        C_CVar.SetCVar("enableFloatingCombatText", "0")
        C_CVar.SetCVar("enableFloatingCombatText", "1")
    end
end

local function GetRowDisplay(entry)
    local val = C_CVar.GetCVar(entry.cvar)
    if val == nil then return "N/A", nil end
    if entry.widget == "checkbox" then
        return nil, C_CVar.GetCVarBool(entry.cvar) == true
    elseif entry.widget == "slider" then
        local num = tonumber(val)
        if num then return FormatSliderVal(num, entry.step), nil end
        return val, nil
    elseif entry.widget == "dropdown" then
        if entry.options and (entry.optLabels or entry.optGlobals) then
            for i, opt in ipairs(entry.options) do
                if val == tostring(opt) then
                    return ToggleOptLabel(entry, i), nil
                end
            end
        end
        return val, nil
    end
    return val, nil
end

--- Human-readable value for list-row indicators (On/Off, option label, or slider text).
local function UpdateRowIndicator(row, entry)
    if not row then return end
    local displayText, isOn = GetRowDisplay(entry)
    if entry.widget == "checkbox" then
        if row.dot then
            row.dot:SetStatus(isOn == true)
        end
    else
        if row.valueText then
            row.valueText:SetText(displayText or "")
        end
    end
end

local function ClearDetailPanel(child)
    OneWoW_GUI:ClearFrame(child)
end

local function ShowToggleDetail(split, entry)
    local child = split.detailScrollChild
    local fw = split.detailScrollFrame:GetWidth()
    if fw > 0 then child:SetWidth(fw) end
    ClearDetailPanel(child)

    local cw   = child:GetWidth() - 24
    local yOfs = -10

    local nameLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameLabel:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    nameLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetText(ToggleName(entry))
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOfs = yOfs - nameLabel:GetStringHeight() - 6

    local cvarLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cvarLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOfs)
    cvarLabel:SetText(L["TOGGLES_CVAR_LABEL"] .. " " .. entry.cvar)
    cvarLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOfs = yOfs - cvarLabel:GetStringHeight() - 10

    local div1 = child:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    div1:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    div1:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOfs = yOfs - 10

    local descText = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    descText:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetSpacing(3)
    descText:SetText(ToggleDesc(entry))
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOfs = yOfs - descText:GetStringHeight() - 12

    local div2 = child:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    div2:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    div2:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOfs = yOfs - 14

    local curVal = C_CVar.GetCVar(entry.cvar)

    if entry.widget == "checkbox" then
        local isOn = C_CVar.GetCVarBool(entry.cvar) == true
        local capturedEntry = entry

        local toggleBtn, _ = OneWoW_GUI:CreateOnOffToggleButtons(child, {
            onLabel = L["TOGGLES_ON"],
            offLabel = L["TOGGLES_OFF"],
            isEnabled = true,
            value = isOn,
            onValueChange = function(newVal)
                SetToggleCVar(capturedEntry.cvar, newVal and "1" or "0")
                UpdateRowIndicator(selectedRow, capturedEntry)
            end,
        })
        toggleBtn:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOfs)

        yOfs = yOfs - 22 - 8

    elseif entry.widget == "slider" then
        local numVal = tonumber(curVal) or entry.min
        numVal = math.max(entry.min, math.min(entry.max, numVal))

        local capturedEntry = entry
        local sliderWrap = OneWoW_GUI:CreateSlider(child, {
            minVal = entry.min,
            maxVal = entry.max,
            step = entry.step or 1,
            currentVal = numVal,
            width = cw,
            getLabel = function(pos)
                return FormatSliderVal(pos, capturedEntry.step)
            end,
            onChange = function(val)
                local fmt = FormatSliderVal(val, capturedEntry.step)
                SetToggleCVar(capturedEntry.cvar, fmt)
                UpdateRowIndicator(selectedRow, capturedEntry)
            end,
        })
        sliderWrap:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOfs)
        yOfs = yOfs - 36 - 8

    elseif entry.widget == "dropdown" then
        local capturedEntry = entry
        local items = {}
        for i, opt in ipairs(entry.options) do
            table.insert(items, {
                text = ToggleOptLabel(entry, i),
                value = tostring(opt),
                isActive = (tostring(opt) == tostring(curVal)),
            })
        end

        local _, finalY = OneWoW_GUI:CreateFitFrameButtons(child, {
            yOffset = yOfs,
            items = items,
            height = 26,
            gap = 4,
            width = child:GetWidth(),
            onSelect = function(value)
                SetToggleCVar(capturedEntry.cvar, value)
                UpdateRowIndicator(selectedRow, capturedEntry)
            end,
        })

        yOfs = finalY - 10
    end

    child:SetHeight(math.abs(yOfs) + 20)
    split.UpdateDetailThumb()
end

local function BuildTogglesList(split, filterText)
    local child = split.listScrollChild
    OneWoW_GUI:ClearFrame(child)
    selectedRow = nil

    local filter    = (filterText and #filterText > 0) and filterText:lower() or nil
    local shownCount = 0

    local yOfs = -5
    local rowH = 30

    local function appendToggleRow(entry)
        local capturedEntry = entry
        local displayText, isOn = GetRowDisplay(entry)

        local rowOptions = {
            height = rowH,
            label = ToggleName(entry),
            onClick = function(self)
                if selectedRow and selectedRow ~= self then
                    selectedRow:SetActive(false)
                end
                selectedRow = self
                ShowToggleDetail(split, capturedEntry)
                self:SetActive(true)
            end,
            favoriteToggle = {
                isFavorite = IsQoLToggleFavorite(entry),
                size = 16,
                tooltipTitle = L["TOGGLES_FAVORITE_TT_TITLE"],
                tooltipText = L["TOGGLES_FAVORITE_TT_DESC"],
                onChange = function(isFav)
                    SetQoLToggleFavorite(capturedEntry, isFav)
                    BuildTogglesList(split, split.searchBox and split.searchBox:GetSearchText() or "")
                end,
            },
        }

        if entry.widget == "checkbox" then
            rowOptions.showDot = true
            rowOptions.dotEnabled = isOn
        else
            rowOptions.showValueText = true
            rowOptions.valueText = displayText or ""
        end

        local row = OneWoW_GUI:CreateListRowBasic(child, rowOptions)
        row:SetPoint("TOPLEFT",  child, "TOPLEFT",  4, yOfs)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, yOfs)
        shownCount = shownCount + 1
        return yOfs - rowH - 3
    end

    local favEntries = {}
    for _, entry in ipairs(CVAR_DATA) do
        if IsQoLToggleFavorite(entry) and ToggleMatchesFilter(entry, filter) then
            table.insert(favEntries, entry)
        end
    end
    table.sort(favEntries, function(a, b)
        return ToggleName(a) < ToggleName(b)
    end)

    if #favEntries > 0 then
        local favLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        favLabel:SetPoint("TOPLEFT",  child, "TOPLEFT",  8, yOfs)
        favLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOfs)
        favLabel:SetJustifyH("LEFT")
        favLabel:SetText(FAVORITES)
        favLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        yOfs = yOfs - favLabel:GetStringHeight() - 4

        for _, entry in ipairs(favEntries) do
            yOfs = appendToggleRow(entry)
        end

        yOfs = yOfs - 8
    end

    for _, cat in ipairs(CATEGORY_ORDER) do
        local catEntries = {}
        for _, entry in ipairs(CVAR_DATA) do
            if entry.cat == cat and not IsQoLToggleFavorite(entry) and ToggleMatchesFilter(entry, filter) then
                table.insert(catEntries, entry)
            end
        end

        if #catEntries > 0 then
            local catLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            catLabel:SetPoint("TOPLEFT",  child, "TOPLEFT",  8, yOfs)
            catLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOfs)
            catLabel:SetJustifyH("LEFT")
            catLabel:SetText(L["TOGGLE_CAT_" .. cat])
            catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            yOfs = yOfs - catLabel:GetStringHeight() - 4

            for _, entry in ipairs(catEntries) do
                yOfs = appendToggleRow(entry)
            end

            yOfs = yOfs - 8
        end
    end

    child:SetHeight(math.abs(yOfs) + 10)
    split.UpdateListThumb()

    if split.leftStatusText then
        if filter then
            split.leftStatusText:SetText(string.format(L["TOGGLES_STATUS_FILTERED"], shownCount, #CVAR_DATA))
        else
            split.leftStatusText:SetText(string.format(L["TOGGLES_STATUS_ALL"], shownCount))
        end
    end
end

function ns.UI.CreateTogglesTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, {
        showSearch = true,
        searchPlaceholder = L["SEARCH_HINT"],
        hideTitles = true,
    })

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            BuildTogglesList(split, self:GetSearchText())
        end)
    end

    C_Timer.After(0.1, function()
        BuildTogglesList(split, "")

        local detailChild = split.detailScrollChild
        local placeholder = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        placeholder:SetPoint("TOP", detailChild, "TOP", 0, -40)
        placeholder:SetWidth(detailChild:GetWidth() - 20)
        placeholder:SetText(L["TOGGLES_NO_SELECTION"])
        placeholder:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        placeholder:SetJustifyH("CENTER")
        detailChild:SetHeight(100)
        split.UpdateDetailThumb()
    end)
end
