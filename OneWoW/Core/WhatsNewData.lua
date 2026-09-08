local _, ns = ...

-- ============================================================================
-- What's New — in-progress release highlight list
-- ============================================================================
-- Concise summary of root CHANGELOG.md for the current cycle (not a full
-- mirror). Up to 7 { titleKey, bodyKey } entries — fewer is fine; do not
-- pad. Reassess when CHANGELOG changes; edit only when the set or wording
-- should change. titleKey/bodyKey resolve through ns.L at show time.
-- Auto-show keys off OneWoW TOC ## Version vs account dismiss
-- (whatsNewDismissedVersion). Policy: OneWoW-Changelog.mdc § What's New /
-- onewow-changelog skill.
-- ============================================================================

ns.WhatsNewData = {
    highlights = {
        { titleKey = "WHATS_NEW_H_ESC_TITLE", bodyKey = "WHATS_NEW_H_ESC_BODY" },
        { titleKey = "WHATS_NEW_H_AFK_TITLE", bodyKey = "WHATS_NEW_H_AFK_BODY" },
        { titleKey = "WHATS_NEW_H_CATALOG_TABS_TITLE", bodyKey = "WHATS_NEW_H_CATALOG_TABS_BODY" },
        { titleKey = "WHATS_NEW_H_CATALOG_NPCS_TITLE", bodyKey = "WHATS_NEW_H_CATALOG_NPCS_BODY" },
        { titleKey = "WHATS_NEW_H_FARMING_LIST_TITLE", bodyKey = "WHATS_NEW_H_FARMING_LIST_BODY" },
        { titleKey = "WHATS_NEW_H_DATABASE_TITLE", bodyKey = "WHATS_NEW_H_DATABASE_BODY" },
        { titleKey = "WHATS_NEW_H_TOOLTIPS_TITLE", bodyKey = "WHATS_NEW_H_TOOLTIPS_BODY" },
    },
}
