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
        { titleKey = "WHATS_NEW_H_FIRSTOPEN_TITLE", bodyKey = "WHATS_NEW_H_FIRSTOPEN_BODY" },
        { titleKey = "WHATS_NEW_H_CRAFTORDERS_TITLE", bodyKey = "WHATS_NEW_H_CRAFTORDERS_BODY" },
        { titleKey = "WHATS_NEW_H_ESCGOLD_TITLE", bodyKey = "WHATS_NEW_H_ESCGOLD_BODY" },
        { titleKey = "WHATS_NEW_H_QUESTAUTO_TITLE", bodyKey = "WHATS_NEW_H_QUESTAUTO_BODY" },
        { titleKey = "WAYPOINT_ARROW", bodyKey = "WHATS_NEW_H_WAYPOINTS_BODY" },
        { titleKey = "MAIL", bodyKey = "WHATS_NEW_H_SHIPMENTS_BODY" },
    },
}
