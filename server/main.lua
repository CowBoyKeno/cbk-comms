local RESOURCE = CBKComms.Config.ResourceName
local PREFIX = CBKComms.Config.Notifications.prefix

local function notify(src, message)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 90, 200, 255 },
        args = { 'CBK-COMMS', message }
    })
end

local function buildJoinNotice(result, departmentKey, channelKey)
    if result and result.mode and result.mode ~= 'single' then
        return ('Patched into %s'):format(result.scopeLabel or 'radio channels')
    end

    local department = CBKComms.DepartmentConfigs[departmentKey]
    local channel = CBKCommsChannels.Get(departmentKey, channelKey)
    local departmentLabel = department and department.label or departmentKey
    local channelLabel = channel and channel.label or channelKey
    return ('Connected to %s %s'):format(departmentLabel, channelLabel)
end

local function pushState(src, closeUi)
    TriggerClientEvent('cbk-comms:client:syncState', src, CBKCommsState.BuildUiState(src), closeUi == true)
end

local function denyUiAccess(src, message)
    TriggerClientEvent('cbk-comms:client:accessDenied', src, {
        reason = message
    })
end

local function collectAffectedDepartments(...)
    local affected = {}

    for index = 1, select('#', ...) do
        local item = select(index, ...)
        if type(item) == 'table' then
            if type(item.department) == 'string' then
                affected[item.department] = true
            end

            for _, channelRef in ipairs(item.listenChannels or {}) do
                if type(channelRef) == 'table' and type(channelRef.department) == 'string' then
                    affected[channelRef.department] = true
                end
            end
        end
    end

    return affected
end

local function refreshMembershipListeners(...)
    local affectedDepartments = collectAffectedDepartments(...)
    if next(affectedDepartments) == nil then
        return
    end

    for _, target in ipairs(GetPlayers()) do
        target = tonumber(target)
        if CBKCommsState.HasAnyAccess(target) then
            for departmentKey, _ in pairs(affectedDepartments) do
                if CBKCommsState.CanViewDepartment(target, departmentKey) then
                    pushState(target, false)
                    break
                end
            end
        end
    end
end

local function getAuthorizedAccess(src, departmentKey)
    local entry = CBKCommsState.GetPlayer(src) or CBKCommsState.RefreshPlayer(src)
    local access = entry.access[departmentKey]
    if not access then
        return nil, 'You are not authorized for that department'
    end
    if entry.radioOn == false then
        return nil, 'Your radio is powered off'
    end
    return access
end

local function getChannelAccess(src, departmentKey, channelKey)
    local entry = CBKCommsState.GetPlayer(src) or CBKCommsState.RefreshPlayer(src)
    local access = CBKCommsState.ResolveChannelAccess(src, departmentKey, channelKey)
    if not access then
        return nil, 'You are not authorized for that channel'
    end
    if entry.radioOn == false then
        return nil, 'Your radio is powered off'
    end
    return access
end

local function requiresDirectFieldLockMembership(departmentKey)
    return departmentKey == 'police'
        or departmentKey == 'ems'
        or departmentKey == 'fire'
        or departmentKey == 'tow'
end

AddEventHandler('playerJoining', function()
    local src = source
    CBKCommsState.RefreshPlayer(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local left, membership = CBKCommsChannels.Leave(src, {
        force = true
    })
    if left and membership then
        refreshMembershipListeners(membership)
    end
    CBKCommsState.RemovePlayer(src)
    CBKCommsSecurity.CleanupPlayer(src)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        CBKCommsState.RefreshPlayer(src)

        if CBKCommsState.HasAnyAccess(src) then
            pushState(src, false)
        else
            denyUiAccess(src)
        end
    end
end)

RegisterNetEvent('cbk-comms:server:requestState', function()
    local src = source

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'requestState',
        CBKComms.Config.Security.uiActionWindowMs,
        CBKComms.Config.Security.uiActionBurst
    ) then
        return
    end

    CBKCommsState.RefreshPlayer(src)

    if not CBKCommsState.HasAnyAccess(src) then
        denyUiAccess(src)
        return
    end

    pushState(src, false)
end)

RegisterNetEvent('cbk-comms:server:openUi', function()
    local src = source

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'openUi',
        CBKComms.Config.Security.uiActionWindowMs,
        CBKComms.Config.Security.uiActionBurst
    ) then
        return
    end

    CBKCommsState.RefreshPlayer(src)

    if not CBKCommsState.HasAnyAccess(src) then
        denyUiAccess(src, 'You are not authorized to use departmental radio')
        return
    end

    pushState(src, false)
    TriggerClientEvent('cbk-comms:client:setUiOpen', src, true)
end)

RegisterNetEvent('cbk-comms:server:setPower', function(payload)
    local src = source
    if type(payload) ~= 'table' or type(payload.enabled) ~= 'boolean' then
        return
    end

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'setPower',
        CBKComms.Config.Security.uiActionWindowMs,
        CBKComms.Config.Security.uiActionBurst
    ) then
        return
    end

    local oldMembership = CBKCommsChannels.GetMembership(src)
    local accessMap = CBKCommsState.GetPlayerAccess(src)

    if payload.enabled ~= true and oldMembership then
        local left, reason = CBKCommsChannels.Leave(src, {
            accessMap = accessMap
        })
        if not left then
            notify(src, reason or 'You cannot power off while on a locked channel')
            pushState(src, false)
            return
        end
    end

    CBKCommsState.SetRadioPower(src, payload.enabled)

    if oldMembership then
        refreshMembershipListeners(oldMembership)
    end

    pushState(src, false)
    notify(src, ('Radio power %s'):format(payload.enabled and 'enabled' or 'disabled'))
end)

RegisterNetEvent('cbk-comms:server:setVolume', function(payload)
    local src = source
    if type(payload) ~= 'table' or not CBKCommsSecurity.IsValidVolume(payload.volume) then
        return
    end

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'setVolume',
        CBKComms.Config.Security.uiActionWindowMs,
        CBKComms.Config.Security.uiActionBurst
    ) then
        return
    end

    local volume = math.floor(payload.volume + 0.0)
    CBKCommsState.SetVolume(src, volume)
    pushState(src, false)
end)

RegisterNetEvent('cbk-comms:server:joinChannel', function(payload)
    local src = source
    if type(payload) ~= 'table' then
        return
    end

    local departmentKey = payload.department
    local channelKey = payload.channel

    if not CBKComms.IsValidDepartmentKey(departmentKey) or not CBKComms.IsValidChannelKey(channelKey) then
        return
    end

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'joinChannel',
        CBKComms.Config.Security.joinWindowMs,
        CBKComms.Config.Security.joinBurst
    ) then
        return
    end

    local access, err = getChannelAccess(src, departmentKey, channelKey)
    if not access then
        notify(src, err)
        pushState(src, false)
        return
    end

    local previousMembership = CBKCommsChannels.GetMembership(src)
    local accessMap = CBKCommsState.GetPlayerAccess(src)
    local ok, result, unchanged = CBKCommsChannels.Join(src, departmentKey, channelKey, access, accessMap)
    if not ok then
        notify(src, result)
        pushState(src, false)
        return
    end

    pushState(src, CBKComms.Config.Radio.autoCloseOnJoin)

    if not unchanged then
        refreshMembershipListeners(previousMembership, result)
    end

    if not unchanged then
        notify(src, buildJoinNotice(result, departmentKey, channelKey))
    end
end)

RegisterNetEvent('cbk-comms:server:togglePatch', function(payload)
    local src = source
    if type(payload) ~= 'table' then
        return
    end

    local departmentKey = payload.department
    local channelKey = payload.channel

    if not CBKComms.IsValidDepartmentKey(departmentKey) or not CBKComms.IsValidChannelKey(channelKey) then
        return
    end

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'togglePatch',
        CBKComms.Config.Security.joinWindowMs,
        CBKComms.Config.Security.joinBurst
    ) then
        return
    end

    local access, err = getChannelAccess(src, departmentKey, channelKey)
    if not access then
        notify(src, err)
        pushState(src, false)
        return
    end

    local accessMap = CBKCommsState.GetPlayerAccess(src)
    local ok, result, _, previousMembership, removing = CBKCommsChannels.TogglePatch(src, departmentKey, channelKey, access, accessMap)
    if not ok then
        notify(src, result)
        pushState(src, false)
        return
    end

    pushState(src, removing ~= true and CBKComms.Config.Radio.autoCloseOnJoin)

    if previousMembership or result then
        refreshMembershipListeners(previousMembership, result)
    end

    local channel = CBKCommsChannels.Get(departmentKey, channelKey)
    local channelLabel = channel and channel.label or channelKey

    if removing then
        notify(src, ('Unpatched %s'):format(channelLabel))
    else
        notify(src, ('Patched %s'):format(channelLabel))
    end
end)

RegisterNetEvent('cbk-comms:server:leaveChannel', function()
    local src = source

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'leaveChannel',
        CBKComms.Config.Security.uiActionWindowMs,
        CBKComms.Config.Security.uiActionBurst
    ) then
        return
    end

    local ok, membership = CBKCommsChannels.Leave(src, {
        accessMap = CBKCommsState.GetPlayerAccess(src)
    })
    pushState(src, false)

    if ok and membership then
        refreshMembershipListeners(membership)
        notify(src, 'Disconnected from radio channel')
    elseif not ok and type(membership) == 'string' then
        notify(src, membership)
    end
end)

RegisterNetEvent('cbk-comms:server:toggleLock', function(payload)
    local src = source
    if type(payload) ~= 'table' then
        return
    end

    local departmentKey = payload.department
    local channelKey = payload.channel
    local shouldLock = payload.locked == true

    if not CBKComms.IsValidDepartmentKey(departmentKey) or not CBKComms.IsValidChannelKey(channelKey) then
        return
    end

    if not CBKCommsSecurity.CanPassRateLimit(
        src,
        'toggleLock',
        CBKComms.Config.Security.lockWindowMs,
        CBKComms.Config.Security.lockBurst
    ) then
        return
    end

    local access = getAuthorizedAccess(src, departmentKey)
    if not access then
        notify(src, 'Unauthorized')
        return
    end

    local tierConfig = CBKComms.Config.Tiers[access.tier]
    if not tierConfig or tierConfig.canLock ~= true then
        notify(src, 'Your hierarchy tier cannot lock channels')
        return
    end

    if requiresDirectFieldLockMembership(departmentKey) then
        local membership = CBKCommsChannels.GetMembership(src)
        if not membership or membership.department ~= departmentKey or membership.channel ~= channelKey then
            notify(src, 'You must be connected to that channel to lock or unlock it')
            return
        end
    end

    local ok, result = CBKCommsChannels.ToggleLock(src, departmentKey, channelKey, shouldLock)
    if not ok then
        notify(src, result)
        return
    end

    refreshMembershipListeners(result)

    notify(src, ('%s %s'):format(CBKCommsChannels.Get(departmentKey, channelKey).label, shouldLock and 'locked' or 'unlocked'))
end)

RegisterCommand('cbkcomms_reload', function(src)
    if src ~= 0 then
        return
    end

    CBKCommsAccess.Reload()
    CBKCommsChannels.Build()

    for _, playerSrc in ipairs(GetPlayers()) do
        playerSrc = tonumber(playerSrc)
        CBKCommsState.RefreshPlayer(playerSrc)
        CBKCommsChannels.Leave(playerSrc, {
            force = true
        })

        if CBKCommsState.HasAnyAccess(playerSrc) then
            pushState(playerSrc, false)
        else
            denyUiAccess(playerSrc)
        end
    end

    print('[cbk-comms] Config reloaded and player states refreshed.')
end, true)

exports('GetPlayerDepartmentAccess', function(src)
    local entry = CBKCommsState.GetPlayer(src) or CBKCommsState.RefreshPlayer(src)
    return entry.access
end)

exports('GetPlayerRadioState', function(src)
    local entry = CBKCommsState.GetPlayer(src) or CBKCommsState.RefreshPlayer(src)
    return {
        radioOn = entry.radioOn,
        volume = entry.volume,
        active = CBKCommsChannels.GetMembership(src)
    }
end)
