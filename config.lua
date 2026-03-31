CBKComms = CBKComms or {}
CBKComms.Config = CBKComms.Config or {}
CBKComms.DepartmentConfigs = CBKComms.DepartmentConfigs or {}

-- Main config for the whole resource.
-- Change values here for global behavior used by every department.
-- Department-specific access lists live in config/*.lua.

-- Basic resource settings.
CBKComms.Config.ResourceName = 'cbk-comms'
CBKComms.Config.Locale = 'en'
CBKComms.Config.Debug = false

-- Keybinds use FiveM key names.
-- openRadio = key used to open/focus the UI.
-- transmit = push-to-talk key for radio transmit.
CBKComms.Config.Keybinds = {
    openRadio = 'F10',
    transmit = 'CAPITAL'
}

-- Shared radio behavior for every player.
-- defaultVolume/minVolume/maxVolume use a 0-100 range.
-- autoCloseOnJoin decides whether the UI closes after a successful join/patch.
-- voiceTargetId normally does not need to be changed unless another voice resource conflicts.
CBKComms.Config.Radio = {
    defaultVolume = 80,
    minVolume = 0,
    maxVolume = 100,
    voiceTargetId = 7,
    useRadioFx = true,
    autoCloseOnJoin = false,

    -- PTT click sounds.
    -- Set enabled = false to disable them completely.
    -- releaseMs controls how long the sound id stays alive before cleanup.
    -- volume can be increased if the click sounds are too quiet in-game.
    pttSounds = {
        enabled = true,
        releaseMs = 450,
        press = {
            name = 'On_High',
            set = 'MP_RADIO_SFX',
            volume = 2.0
        },
        release = {
            name = 'Off_High',
            set = 'MP_RADIO_SFX',
            volume = 1.8
        }
    }
}

-- Simple anti-spam limits for incoming UI/server events.
-- Raise these only if normal use is being blocked during real gameplay.
CBKComms.Config.Security = {
    uiActionWindowMs = 250,
    uiActionBurst = 8,
    joinWindowMs = 1500,
    joinBurst = 4,
    lockWindowMs = 2000,
    lockBurst = 3
}

-- Global department/channel layout.
-- order controls display order and the voice-channel numbering order.
-- baseVoiceChannel should stay on a range not used by another voice system.
-- channel keys here must match the keys used inside each department file.
CBKComms.Config.Departments = {
    order = { 'admin', 'police', 'ems', 'fire', 'tow', 'dispatch' },
    baseVoiceChannel = 41000,
    channels = {
        primary = { offset = 1, label = 'Primary', lockable = false },
        alpha = { offset = 2, label = 'Alpha', lockable = true },
        bravo = { offset = 3, label = 'Bravo', lockable = true }
    }
}

-- Identifier types accepted when matching ids in the department member lists.
-- You can remove identifier types you do not use, but keep the same prefix format in config/*.lua.
CBKComms.Config.Access = {
    identifierTypes = {
        'license',
        'license2',
        'discord',
        'fivem',
        'steam',
        'xbl',
        'live'
    }
}

-- Shared tier capability map.
-- Department files decide what each tier is called, but canLock/canManage come from here.
-- In the current setup, tiers 4 and 5 are the lock-capable tiers.
CBKComms.Config.Tiers = {
    [1] = { label = 'Tier 1', canLock = false, canManage = false },
    [2] = { label = 'Tier 2', canLock = false, canManage = false },
    [3] = { label = 'Tier 3', canLock = false, canManage = false },
    [4] = { label = 'Tier 4', canLock = true, canManage = true },
    [5] = { label = 'Tier 5', canLock = true, canManage = true }
}

-- Radio audio effect settings.
-- Most servers can leave these at the defaults.
CBKComms.Config.RadioFx = {
    effectSlot = 1,
    default = 1,
    freqLow = 320.0,
    freqHi = 6200.0
}

-- Chat prefix used for simple server-side notifications.
CBKComms.Config.Notifications = {
    prefix = '^5[CBK-COMMS]^7 '
}
