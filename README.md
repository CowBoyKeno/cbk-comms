# CBK COMMUNICATIONS #

Standalone, server-authoritative radio communications resource for public FiveM servers.

## Highlights

- `F10` radio with no external framework dependency
- Field handset UI for `Police`, `EMS`, `Fire`, and `Tow`
- Console-style panel for `Admin` and `Dispatch`
- Three channels per department: `Primary`, `Alpha`, `Bravo`
- Server-authoritative joins, leaves, patching, power state, volume, and locks
- Mumble voice listeners plus radio submix support so radio traffic can coexist with proximity voice
- Rate-limited inbound events and config hot reload support

## Current channel model

- `Primary` is available on every department and is not lockable by default.
- `Alpha` and `Bravo` are lockable channels.
- `Secondary` channels are no longer part of this resource.

## Department behavior

### Field departments

`Police`, `EMS`, `Fire`, and `Tow` use the radio handset UI and only see their own department comms.

- Tiers `4` and `5` can lock or unlock lockable field channels.
- For field departments, the player must be directly connected to that exact channel before they can lock or unlock it.

### Dispatch

`Dispatch` uses the console panel and has a single tier:

- `1 = DISPATCH`

Dispatch can access primary channels across departments through the console view.

- Dispatch patch buttons behave like toggles.
- Dispatch can patch into multiple visible primary channels at the same time.
- Dispatch only sees channels it can actually use in the console.

### Admin

`Admin` uses the console panel and has two tiers:

- `4 = ADMIN`
- `5 = OWNER`

Admin access rules:

- `ADMIN` can access cross-department channels when they are unlocked.
- `OWNER` can also enter locked channels.
- `ADMIN` and `OWNER` can leave locked channels.

## Lock behavior

Locks are enforced on the server.

- When a channel is locked, non-exempt users already on that channel stay pinned there until it is unlocked.
- `ADMIN` and `OWNER` can still leave a locked channel.
- Only the player who locked a channel can manually unlock it.
- If the locker leaves the channel, switches away, powers off, disconnects, or the resource clears their membership, the lock auto-unlocks.

## UI behavior

- `F10` opens the radio or console.
- `Close On Join` controls whether the UI closes after a successful join or patch action.
- If the UI stays open, right-click releases focus and hides the cursor so the player can continue playing without closing the radio.
- The field handset layout is movable and resizable, and the client remembers the saved layout locally.

## Install

1. Drop `cbk-comms` into your resources folder.
2. Replace the placeholder identifiers in `config/*.lua`.
3. Remove any unused placeholder member entries before production deployment.
4. Add `ensure cbk-comms` to your `server.cfg` after `chat`.
5. Recommended client convar for better radio effect:
   - `setr voice_useNativeAudio true`

## Config model

Each department config file supports multiple identifiers on one member entry, and the shipped configs now include one active placeholder member entry for every defined tier:

```lua
members = {
    {
        label = 'Police Tier 1',
        tier = 1,
        ids = {
            'license:replace_with_police_tier1_license',
            'discord:replace_with_police_tier1_discord_id',
            'fivem:replace_with_police_tier1_fivem_id'
        }
    },
    {
        label = 'Police Supervisor',
        tier = 4,
        ids = {
            'license:replace_with_police_supervisor_license',
            'discord:replace_with_police_supervisor_discord_id',
            'fivem:replace_with_police_supervisor_fivem_id'
        }
    }
}
```

Important:

- Placeholder entries are active config entries, not comments.
- A player will only match a tier after you replace that tier's placeholder identifiers with real ones.
- If a department should not use a tier yet, remove that placeholder member block instead of leaving fake IDs in place.

Identifier matching is deterministic.

- Department members are evaluated in the order they are listed in the config.
- Identifiers inside each member entry are also checked in the order they are listed.
- The first matching member entry grants access for that department.

Global defaults live in [config.lua](../config.lua).

- `CBKComms.Config.Radio` controls volume defaults, PTT sounds, radio FX, and `autoCloseOnJoin`.
- `CBKComms.Config.Security` controls rate-limit windows and burst limits.
- `CBKComms.Config.Departments` defines department order, base voice channel range, and shared channel definitions.
- `CBKComms.Config.Tiers` defines the shared tier capability map used by the lock checks.

## Security notes

- All mutating actions are validated on the server.
- Clients never self-authorize a department, tier, join, patch, or lock action.
- Lock ownership is enforced server-side.
- Channel state and membership counts are derived from server state.
- Event spam is rate-limited.

## Commands / exports

### Server command

- `cbkcomms_reload` - reload whitelist configs, rebuild channels, clear active memberships, and refresh connected players

### Server exports

- `exports['cbk-comms']:GetPlayerDepartmentAccess(source)`
- `exports['cbk-comms']:GetPlayerRadioState(source)`

## Architecture note

This resource uses Mumble voice listeners plus `MumbleAddVoiceChannelListen` so radio traffic can coexist with normal proximity voice, instead of moving players fully out of the root voice channel.
