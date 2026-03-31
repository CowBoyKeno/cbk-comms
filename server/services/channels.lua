CBKCommsChannels = {
    channels = {},
    members = {}
}

local function computeVoiceChannelId(departmentKey, channelKey)
    local deptIndex = 0
    for index, key in ipairs(CBKComms.Config.Departments.order) do
        if key == departmentKey then
            deptIndex = index
            break
        end
    end

    if deptIndex == 0 then
        error(('cbk-comms missing department ordering for %s'):format(departmentKey))
    end

    local channelConfig = CBKComms.Config.Departments.channels[channelKey]
    if not channelConfig then
        error(('cbk-comms missing channel config for %s'):format(channelKey))
    end

    return CBKComms.Config.Departments.baseVoiceChannel + ((deptIndex - 1) * 10) + channelConfig.offset
end

local function channelId(departmentKey, channelKey)
    return ('%s:%s'):format(departmentKey, channelKey)
end

local function sanitizeMembers(memberSet)
    local result = {}
    for src, _ in pairs(memberSet or {}) do
        if GetPlayerName(src) then
            result[#result + 1] = tonumber(src)
        end
    end
    table.sort(result)
    return result
end

local function shouldCountLinkedMember(channel, src)
    local membership = CBKCommsChannels.members[src]
    if not membership then
        return false
    end

    return membership.mode == 'single'
        and membership.department == channel.department
        and membership.channel == channel.key
end

local function countLinkedMembers(channel)
    local count = 0

    for src, _ in pairs(channel and channel.members or {}) do
        if GetPlayerName(src) and shouldCountLinkedMember(channel, src) then
            count = count + 1
        end
    end

    return count
end

local function canEnterLockedChannel(channel, src, access)
    return not channel.locked or channel.lockedBy == src or (access and access.canBypassLock == true)
end

local membershipIncludesChannel

local function unlockOwnedFocusedChannel(src, current, nextMembership)
    if not current then
        return nil
    end

    local currentChannel = CBKCommsChannels.Get(current.department, current.channel)
    if not currentChannel or currentChannel.locked ~= true or currentChannel.lockedBy ~= src then
        return nil
    end

    if membershipIncludesChannel(nextMembership, current.department, current.channel) then
        return nil
    end

    currentChannel.locked = false
    currentChannel.lockedBy = nil

    return {
        department = current.department,
        channel = current.channel,
        locked = false,
        lockedBy = nil
    }
end

membershipIncludesChannel = function(membership, departmentKey, channelKey)
    for _, channelRef in ipairs((membership and membership.listenChannels) or {}) do
        if channelRef.department == departmentKey and channelRef.channel == channelKey then
            return true
        end
    end

    return false
end

local function cloneChannelSet(channelRefs)
    local result = {}

    for _, channelRef in ipairs(channelRefs or {}) do
        if channelRef.id then
            result[channelRef.id] = true
        end
    end

    return result
end

local function getConsoleRole(accessMap)
    if accessMap and accessMap.admin then
        return 'admin'
    end

    if accessMap and accessMap.dispatch then
        return 'dispatch'
    end

    return nil
end

local function ensureVoiceChannelExists(voiceChannelId)
    if type(voiceChannelId) ~= 'number' then
        return
    end

    if type(MumbleDoesChannelExist) == 'function' and MumbleDoesChannelExist(voiceChannelId) then
        return
    end

    if type(MumbleCreateChannel) ~= 'function' then
        return
    end

    local ok, err = pcall(MumbleCreateChannel, voiceChannelId)
    if not ok and CBKComms.Config.Debug then
        print(('[cbk-comms][server] failed to create mumble channel %s: %s'):format(voiceChannelId, err))
    end
end

local function serializeChannelRefs(channelSet)
    local result = {}

    for id, _ in pairs(channelSet or {}) do
        local channel = CBKCommsChannels.GetById(id)
        if channel then
            result[#result + 1] = {
                id = channel.id,
                department = channel.department,
                channel = channel.key,
                label = channel.label,
                voiceChannelId = channel.voiceChannelId
            }
        end
    end

    table.sort(result, function(left, right)
        return left.voiceChannelId < right.voiceChannelId
    end)

    return result
end

local function collectDispatchPrimaryChannels(accessMap)
    local result = {}

    for _, departmentKey in ipairs(CBKComms.Config.Departments.order) do
        local access = CBKCommsState.ResolveChannelAccessForMap(accessMap, departmentKey, 'primary')
        if access then
            local channel = CBKCommsChannels.Get(departmentKey, 'primary')
            if channel then
                result[channel.id] = true
            end
        end
    end

    return result
end

local function buildMembership(departmentKey, channelKey, accessMap)
    local selectedChannel = CBKCommsChannels.Get(departmentKey, channelKey)
    if not selectedChannel then
        return nil
    end

    local listenSet = {
        [selectedChannel.id] = true
    }
    local transmitSet = {
        [selectedChannel.id] = true
    }
    local mode = 'single'
    local scopeLabel = selectedChannel.label

    if accessMap and accessMap.admin then
        mode = 'admin_all'
        scopeLabel = 'All Channels'

        for id, _ in pairs(CBKCommsChannels.channels) do
            listenSet[id] = true
            transmitSet[id] = true
        end
    elseif accessMap and accessMap.dispatch then
        local primarySet = collectDispatchPrimaryChannels(accessMap)

        if next(primarySet) ~= nil then
            mode = 'dispatch_primary'
            scopeLabel = channelKey == 'primary'
                and 'All Primary Channels'
                or ('All Primary + %s'):format(selectedChannel.label)

            for id, _ in pairs(primarySet) do
                listenSet[id] = true
                transmitSet[id] = true
            end
        end
    end

    local departmentConfig = CBKComms.DepartmentConfigs[departmentKey]
    local departmentLabel = departmentConfig and departmentConfig.label or departmentKey

    return {
        department = departmentKey,
        channel = channelKey,
        mode = mode,
        scopeLabel = scopeLabel,
        focusLabel = ('%s / %s'):format(departmentLabel, selectedChannel.label),
        listenChannels = serializeChannelRefs(listenSet),
        transmitChannels = serializeChannelRefs(transmitSet)
    }
end

local function buildConsoleMembership(departmentKey, channelKey, channelSet, consoleRole)
    local listenChannels = serializeChannelRefs(channelSet)
    if #listenChannels == 0 then
        return nil
    end

    local selectedChannel = CBKCommsChannels.Get(departmentKey, channelKey)
    if not selectedChannel then
        departmentKey = listenChannels[1].department
        channelKey = listenChannels[1].channel
        selectedChannel = CBKCommsChannels.Get(departmentKey, channelKey)
    end

    if not selectedChannel then
        return nil
    end

    local departmentConfig = CBKComms.DepartmentConfigs[departmentKey]
    local departmentLabel = departmentConfig and departmentConfig.label or departmentKey
    local scopeLabel = consoleRole == 'admin' and 'Admin Patch' or 'Dispatch Patch'

    if #listenChannels == 1 then
        scopeLabel = selectedChannel.label
    end

    return {
        department = departmentKey,
        channel = channelKey,
        mode = consoleRole == 'admin' and 'admin_console' or 'dispatch_console',
        consoleRole = consoleRole,
        scopeLabel = scopeLabel,
        focusLabel = ('%s / %s'):format(departmentLabel, selectedChannel.label),
        listenChannels = listenChannels,
        transmitChannels = serializeChannelRefs(channelSet)
    }
end

local clearMembership

local function applyMembership(src, membership)
    local current = CBKCommsChannels.members[src]
    unlockOwnedFocusedChannel(src, current, membership)
    clearMembership(src)

    if not membership then
        return true
    end

    for _, channelRef in ipairs(membership.listenChannels or {}) do
        local listenChannel = CBKCommsChannels.GetById(channelRef.id)
        if listenChannel then
            listenChannel.members[src] = true
        end
    end

    CBKCommsChannels.members[src] = membership
    return true
end

local function membershipChannels(membership, key)
    local result = {}

    for _, channelRef in ipairs((membership and membership[key]) or {}) do
        result[#result + 1] = channelRef
    end

    return result
end

clearMembership = function(src)
    local current = CBKCommsChannels.members[src]
    if not current then
        return nil
    end

    for _, channelRef in ipairs(membershipChannels(current, 'listenChannels')) do
        local channel = CBKCommsChannels.GetById(channelRef.id)
        if channel then
            channel.members[src] = nil
        end
    end

    CBKCommsChannels.members[src] = nil
    return current
end

local function canLeaveMembership(src, current, nextMembership, accessMap)
    if not current then
        return true
    end

    local currentChannel = CBKCommsChannels.Get(current.department, current.channel)
    if not currentChannel or not currentChannel.locked then
        return true
    end

    local currentAccess = CBKCommsState.ResolveChannelAccessForMap(accessMap or CBKCommsState.GetPlayerAccess(src), current.department, current.channel)
    if currentAccess and currentAccess.canLeaveLocked == true then
        return true
    end

    if currentChannel.lockedBy == src then
        return true
    end

    if membershipIncludesChannel(nextMembership, current.department, current.channel) then
        return true
    end

    return false, ('%s is locked until it is unlocked'):format(currentChannel.label)
end

function CBKCommsChannels.Build()
    CBKCommsChannels.channels = {}
    for _, departmentKey in ipairs(CBKComms.Config.Departments.order) do
        local deptConfig = CBKComms.DepartmentConfigs[departmentKey]
        if deptConfig and deptConfig.enabled then
            for channelKey, globalConfig in pairs(CBKComms.Config.Departments.channels) do
                local deptChannelCfg = (deptConfig.channels or {})[channelKey] or {}
                local id = channelId(departmentKey, channelKey)
                CBKCommsChannels.channels[id] = {
                    id = id,
                    department = departmentKey,
                    key = channelKey,
                    label = deptChannelCfg.label or globalConfig.label,
                    voiceChannelId = computeVoiceChannelId(departmentKey, channelKey),
                    lockable = deptChannelCfg.lockable == true or globalConfig.lockable == true,
                    locked = false,
                    lockedBy = nil,
                    members = {}
                }

                ensureVoiceChannelExists(CBKCommsChannels.channels[id].voiceChannelId)
            end
        end
    end
end

CBKCommsChannels.Build()

function CBKCommsChannels.Get(departmentKey, channelKey)
    return CBKCommsChannels.channels[channelId(departmentKey, channelKey)]
end

function CBKCommsChannels.GetById(id)
    return CBKCommsChannels.channels[id]
end

function CBKCommsChannels.GetMembership(src)
    return CBKCommsChannels.members[src]
end

function CBKCommsChannels.Leave(src, options)
    options = options or {}

    local current = CBKCommsChannels.members[src]
    if not current then
        return false, nil
    end

    if options.force ~= true then
        local ok, reason = canLeaveMembership(src, current, nil, options.accessMap)
        if not ok then
            return false, reason
        end
    end

    unlockOwnedFocusedChannel(src, current, nil)
    clearMembership(src)
    return true, current
end

function CBKCommsChannels.Join(src, departmentKey, channelKey, access, accessMap)
    local channel = CBKCommsChannels.Get(departmentKey, channelKey)
    if not channel then
        return false, 'Invalid channel'
    end

    if not canEnterLockedChannel(channel, src, access) then
        return false, 'This channel is currently locked'
    end

    local current = CBKCommsChannels.members[src]
    if current and current.department == departmentKey and current.channel == channelKey then
        return true, current, true
    end

    local membership = buildMembership(departmentKey, channelKey, accessMap or {})
    if not membership then
        return false, 'Invalid channel'
    end

    local ok, reason = canLeaveMembership(src, current, membership, accessMap)
    if not ok then
        return false, reason
    end

    applyMembership(src, membership)

    return true, membership, false
end

function CBKCommsChannels.TogglePatch(src, departmentKey, channelKey, access, accessMap)
    local channel = CBKCommsChannels.Get(departmentKey, channelKey)
    if not channel then
        return false, 'Invalid channel'
    end

    if not canEnterLockedChannel(channel, src, access) then
        return false, 'This channel is currently locked'
    end

    local consoleRole = getConsoleRole(accessMap)
    if not consoleRole then
        return false, 'Console patching is unavailable'
    end

    local current = CBKCommsChannels.members[src]
    local nextChannelSet = cloneChannelSet(current and current.listenChannels)
    local targetChannelId = channel.id
    local removing = nextChannelSet[targetChannelId] == true

    if removing then
        nextChannelSet[targetChannelId] = nil
    else
        nextChannelSet[targetChannelId] = true
    end

    if next(nextChannelSet) == nil then
        local previous = current
        local ok, reason = canLeaveMembership(src, current, nil, accessMap)
        if not ok then
            return false, reason
        end
        applyMembership(src, nil)
        return true, nil, false, previous, removing
    end

    local nextDepartmentKey = departmentKey
    local nextChannelKey = channelKey

    if removing then
        local currentChannelId = current and current.department and current.channel and channelId(current.department, current.channel) or nil
        if currentChannelId and nextChannelSet[currentChannelId] then
            nextDepartmentKey = current.department
            nextChannelKey = current.channel
        else
            local remainingChannels = serializeChannelRefs(nextChannelSet)
            nextDepartmentKey = remainingChannels[1].department
            nextChannelKey = remainingChannels[1].channel
        end
    end

    local membership = buildConsoleMembership(nextDepartmentKey, nextChannelKey, nextChannelSet, consoleRole)
    if not membership then
        return false, 'Invalid channel'
    end

    local previous = current
    local ok, reason = canLeaveMembership(src, current, membership, accessMap)
    if not ok then
        return false, reason
    end
    applyMembership(src, membership)

    return true, membership, false, previous, removing
end

function CBKCommsChannels.ToggleLock(src, departmentKey, channelKey, shouldLock)
    local channel = CBKCommsChannels.Get(departmentKey, channelKey)
    if not channel then
        return false, 'Invalid channel'
    end

    if not channel.lockable then
        return false, 'This channel cannot be locked'
    end

    if shouldLock == true then
        if channel.locked and channel.lockedBy ~= src then
            return false, ('%s is already locked'):format(channel.label)
        end
    elseif channel.locked then
        if channel.lockedBy ~= src then
            return false, 'Only the player who locked this channel can unlock it'
        end
    else
        return true, {
            department = departmentKey,
            channel = channelKey,
            locked = false,
            lockedBy = nil
        }
    end

    channel.locked = shouldLock == true
    channel.lockedBy = channel.locked and src or nil

    return true, {
        department = departmentKey,
        channel = channelKey,
        locked = channel.locked,
        lockedBy = channel.lockedBy
    }
end

function CBKCommsChannels.SerializeDepartmentChannels()
    local result = {}
    for _, departmentKey in ipairs(CBKComms.Config.Departments.order) do
        local deptChannels = {}
        for channelKey, _ in pairs(CBKComms.Config.Departments.channels) do
            local channel = CBKCommsChannels.Get(departmentKey, channelKey)
            if channel then
                deptChannels[channelKey] = {
                    id = channel.id,
                    department = channel.department,
                    key = channel.key,
                    label = channel.label,
                    voiceChannelId = channel.voiceChannelId,
                    lockable = channel.lockable,
                    locked = channel.locked,
                    memberCount = 0,
                    memberServerIds = {}
                }
            end
        end
        result[departmentKey] = deptChannels
    end
    return result
end

function CBKCommsChannels.PopulateCounts(payload)
    for departmentKey, channels in pairs(payload or {}) do
        for channelKey, info in pairs(channels) do
            local channel = CBKCommsChannels.Get(departmentKey, channelKey)
            if channel then
                info.memberServerIds = sanitizeMembers(channel.members)
                info.memberCount = countLinkedMembers(channel)
            end
        end
    end
end
