-- Dispatch department config.
-- Dispatch uses the console UI and can patch into visible primary channels.
-- Replace the placeholder ids below with real dispatcher ids.
-- The first matching member entry grants access.

CBKComms.DepartmentConfigs['dispatch'] = {
    -- Turn this whole department on or off.
    enabled = true,

    -- Display values used in the UI.
    label = 'Dispatch',
    shortLabel = 'DISP',
    color = '#a855f7',

    -- Channel labels shown in the UI.
    channels = {
        primary = { label = 'DISP-Primary' },
        alpha = { label = 'DISP-Alpha', lockable = true },
        bravo = { label = 'DISP-Bravo', lockable = true }
    },

    -- Dispatch has one tier only.
    tiers = {
        [1] = 'DISPATCH'
    },

    -- This block is active.
    -- Replace the placeholder ids with real ids for the dispatcher.
    members = {
        {
            label = 'Dispatch',
            tier = 1,
            ids = {
                'license:replace_with_dispatch_license',
                'fivem:replace_with_dispatch_fivem_id',
                'discord:replace_with_dispatch_discord_id',
                'steam:replace_with_dispatch_steam_id'
            }
        }
    }
}
