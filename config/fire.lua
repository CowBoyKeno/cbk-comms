-- Fire department config.
-- Fire uses the handheld radio UI.
-- Replace each placeholder id with a real id for that tier/member.
-- If you do not use a tier yet, remove that member block entirely.
-- Tiers 4 and 5 are the lock-capable tiers for field channels.

CBKComms.DepartmentConfigs['fire'] = {
    -- Turn this whole department on or off.
    enabled = true,

    -- Display values used in the UI.
    label = 'Fire',
    shortLabel = 'FIRE',
    color = '#f97316',

    -- Channel labels shown in the UI.
    channels = {
        primary = { label = 'FIRE-Primary' },
        alpha = { label = 'FIRE-Alpha', lockable = true },
        bravo = { label = 'FIRE-Bravo', lockable = true }
    },

    -- Department-specific tier names shown to the player.
    tiers = {
        [1] = 'Fire Tier 1',
        [2] = 'Fire Tier 2',
        [3] = 'Fire Tier 3',
        [4] = 'Fire Supervisor',
        [5] = 'Fire Command'
    },

    -- Every block below is active.
    -- The first matching member entry grants access, so order matters.
    -- Keep multiple ids for the same person inside the same ids list.
    members = {
        {
            label = 'Fire Tier 1',
            tier = 1,
            ids = {
                'license:replace_with_fire_tier1_license',
                'fivem:replace_with_fire_tier1_fivem_id',
                'discord:replace_with_fire_tier1_discord_id',
                'steam:replace_with_fire_tier1_steam_id'
            }
        },
        {
            label = 'Fire Tier 2',
            tier = 2,
            ids = {
                'license:replace_with_fire_tier2_license',
                'fivem:replace_with_fire_tier2_fivem_id',
                'discord:replace_with_fire_tier2_discord_id',
                'steam:replace_with_fire_tier2_steam_id'
            }
        },
        {
            label = 'Fire Tier 3',
            tier = 3,
            ids = {
                'license:replace_with_fire_tier3_license',
                'fivem:replace_with_fire_tier3_fivem_id',
                'discord:replace_with_fire_tier3_discord_id',
                'steam:replace_with_fire_tier3_steam_id'
            }
        },
        {
            label = 'Fire Supervisor',
            tier = 4,
            ids = {
                'license:replace_with_fire_supervisor_license',
                'fivem:replace_with_fire_supervisor_fivem_id',
                'discord:replace_with_fire_supervisor_discord_id',
                'steam:replace_with_fire_supervisor_steam_id'
            }
        },
        {
            label = 'Fire Command',
            tier = 5,
            ids = {
                'license:replace_with_fire_command_license',
                'fivem:replace_with_fire_command_fivem_id',
                'discord:replace_with_fire_command_discord_id',
                'steam:replace_with_fire_command_steam_id'
            }
        }
    }
}
