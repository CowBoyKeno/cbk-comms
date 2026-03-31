-- EMS department config.
-- EMS uses the handheld radio UI.
-- Replace each placeholder id with a real id for that tier/member.
-- If you do not use a tier yet, remove that member block entirely.
-- Tiers 4 and 5 are the lock-capable tiers for field channels.

CBKComms.DepartmentConfigs['ems'] = {
    -- Turn this whole department on or off.
    enabled = true,

    -- Display values used in the UI.
    label = 'EMS',
    shortLabel = 'EMS',
    color = '#ef4444',

    -- Channel labels shown in the UI.
    channels = {
        primary = { label = 'EMS-Primary' },
        alpha = { label = 'EMS-Alpha', lockable = true },
        bravo = { label = 'EMS-Bravo', lockable = true }
    },

    -- Department-specific tier names shown to the player.
    tiers = {
        [1] = 'EMS Tier 1',
        [2] = 'EMS Tier 2',
        [3] = 'EMS Tier 3',
        [4] = 'EMS Supervisor',
        [5] = 'EMS Command'
    },

    -- Every block below is active.
    -- The first matching member entry grants access, so order matters.
    -- Keep multiple ids for the same person inside the same ids list.
    members = {
        {
            label = 'EMS Tier 1',
            tier = 1,
            ids = {
                'license:replace_with_ems_tier1_license',
                'fivem:replace_with_ems_tier1_fivem_id',
                'discord:replace_with_ems_tier1_discord_id',
                'steam:replace_with_ems_tier1_steam_id'
            }
        },
        {
            label = 'EMS Tier 2',
            tier = 2,
            ids = {
                'license:replace_with_ems_tier2_license',
                'fivem:replace_with_ems_tier2_fivem_id',
                'discord:replace_with_ems_tier2_discord_id',
                'steam:replace_with_ems_tier2_steam_id'
            }
        },
        {
            label = 'EMS Tier 3',
            tier = 3,
            ids = {
                'license:replace_with_ems_tier3_license',
                'fivem:replace_with_ems_tier3_fivem_id',
                'discord:replace_with_ems_tier3_discord_id',
                'steam:replace_with_ems_tier3_steam_id'
            }
        },
        {
            label = 'EMS Supervisor',
            tier = 4,
            ids = {
                'license:replace_with_ems_supervisor_license',
                'fivem:replace_with_ems_supervisor_fivem_id',
                'discord:replace_with_ems_supervisor_discord_id',
                'steam:replace_with_ems_supervisor_steam_id'
            }
        },
        {
            label = 'EMS Command',
            tier = 5,
            ids = {
                'license:replace_with_ems_command_license',
                'fivem:replace_with_ems_command_fivem_id',
                'discord:replace_with_ems_command_discord_id',
                'steam:replace_with_ems_command_steam_id'
            }
        }
    }
}
