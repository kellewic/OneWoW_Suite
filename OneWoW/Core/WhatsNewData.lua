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
        { titleKey = "WHATS_NEW_H_AFK_TITLE", bodyKey = "WHATS_NEW_H_AFK_BODY" },
        { titleKey = "WHATS_NEW_H_CRAFTORDERS_TITLE", bodyKey = "WHATS_NEW_H_CRAFTORDERS_BODY" },
        { titleKey = "WHATS_NEW_H_AUCTIONS_TITLE", bodyKey = "WHATS_NEW_H_AUCTIONS_BODY" },
        { titleKey = "WHATS_NEW_H_TOOLTIPS_TITLE", bodyKey = "WHATS_NEW_H_TOOLTIPS_BODY" },
        { titleKey = "MODULE_CATALOG", bodyKey = "WHATS_NEW_H_CATALOG_BODY" },
        { titleKey = "MODULE_TRACKERS", bodyKey = "WHATS_NEW_H_TRACKERS_BODY" },
    },
}
