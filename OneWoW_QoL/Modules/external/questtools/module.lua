local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "questtools",
    title       = "QUESTTOOLS_TITLE",
    category    = "AUTOMATION",
    description = "QUESTTOOLS_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles = {
        { id = "auto_accept",  label = "QUESTTOOLS_TOGGLE_ACCEPT",  description = "QUESTTOOLS_TOGGLE_ACCEPT_DESC",  default = true  },
        { id = "auto_turnin",  label = "QUESTTOOLS_TOGGLE_TURNIN",  description = "QUESTTOOLS_TOGGLE_TURNIN_DESC",  default = true  },
        { id = "reward_picker",label = "QUESTTOOLS_TOGGLE_REWARDS", description = "QUESTTOOLS_TOGGLE_REWARDS_DESC", default = true  },
        { id = "auto_gossip",  label = "QUESTTOOLS_TOGGLE_GOSSIP",  description = "QUESTTOOLS_TOGGLE_GOSSIP_DESC",  default = false },
        { id = "require_modifier", label = "QUESTTOOLS_REQUIRE_MODIFIER", description = "QUESTTOOLS_REQUIRE_MODIFIER_DESC", default = false, detailOnly = true },
    },
    preview       = true,
    _acceptFrame  = nil,
    _turninFrame  = nil,
    _gossipFrame  = nil,
    _gossipHooked = false,
    _gossipRetryToken = 0,
    _goldIcon     = nil,
})
