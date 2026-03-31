-- Admin department config.
-- Admin uses the console UI, not the handheld radio shell.
-- Replace the placeholder ids below with real ids for your staff.
-- If you do not need a tier yet, remove that member block entirely.
-- The first matching member entry grants access, so keep the list in the order you want checked.

CBKComms.DepartmentConfigs['admin'] = {
    -- Turn this whole department on or off.
    enabled = true,

    -- Display values used in the UI.
    label = 'Administration',
    shortLabel = 'ADMIN',
    color = '#eab308',

    -- Channel labels shown in the UI.
    channels = {
        primary = { label = 'ADMIN-Primary' },
        alpha = { label = 'ADMIN-Alpha', lockable = true },
        bravo = { label = 'ADMIN-Bravo', lockable = true }
    },

    -- Admin has two tiers:
    -- 4 = ADMIN
    -- 5 = OWNER
    tiers = {
        [4] = 'ADMIN',
        [5] = 'OWNER'
    },

    -- Every block below is active.
    -- A player only matches after you replace these placeholder ids with real ones.
    -- Keep multiple ids on the same person in the same block.
    members = {
        {
            label = 'Admin',
            tier = 4,
            ids = {
                'license:replace_with_admin_license',
                'fivem:replace_with_admin_fivem_id',
                'discord:replace_with_admin_discord_id',
                'steam:replace_with_admin_steam_id'
            }
        },
        {
            label = 'Owner',
            tier = 5,
            ids = {
                'license:replace_with_owner_license',
                'fivem:replace_with_owner_fivem_id',
                'discord:replace_with_owner_discord_id',
                'steam:replace_with_owner_steam_id'
            }
        }
    }
}
