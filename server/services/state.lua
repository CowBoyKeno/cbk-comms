CBKCommsState = {
    players = {}
}

local function cloneChannelAccess(departmentKey, access, accessMode, options)
    options = options or {}

    return {
        department = departmentKey,
        tier = access and access.tier or 0,
        tierLabel = options.tierLabel or (access and access.tierLabel) or 'Unauthorized',
        memberLabel = options.memberLabel or (access and access.memberLabel) or '',
        accessMode = accessMode or 'direct',
        canBypassLock = options.canBypassLock == true,
        canLeaveLocked = options.canLeaveLocked == true
    }
end

local function isAdminTier(accessMap)
    return type(accessMap) == 'table'
        and type(accessMap.admin) == 'table'
        and type(accessMap.admin.tier) == 'number'
        and accessMap.admin.tier >= 4
end

local function isOwnerTier(accessMap)
    return type(accessMap) == 'table'
        and type(accessMap.admin) == 'table'
        and type(accessMap.admin.tier) == 'number'
        and accessMap.admin.tier >= 5
end

local function resolveChannelAccess(accessMap, departmentKey, channelKey)
    accessMap = accessMap or {}

    local directAccess = accessMap[departmentKey]
    if directAccess then
        return cloneChannelAccess(departmentKey, directAccess, 'direct', {
            canBypassLock = isOwnerTier(accessMap),
            canLeaveLocked = isAdminTier(accessMap)
        })
    end

    local adminAccess = accessMap.admin
    if adminAccess then
        return cloneChannelAccess(departmentKey, adminAccess, 'admin_override', {
            tierLabel = 'Admin Override',
            memberLabel = 'Administration cross-department access',
            canBypassLock = isOwnerTier(accessMap),
            canLeaveLocked = isAdminTier(accessMap)
        })
    end

    local dispatchAccess = accessMap.dispatch
    if dispatchAccess and channelKey == 'primary' and departmentKey ~= 'admin' then
        return cloneChannelAccess(departmentKey, dispatchAccess, 'dispatch_primary', {
            tierLabel = 'Dispatch Primary',
            memberLabel = 'Dispatch access to all primary channels'
        })
    end

    return nil
end

local function canViewDepartment(accessMap, departmentKey)
    accessMap = accessMap or {}

    return accessMap.admin ~= nil
        or accessMap.dispatch ~= nil
        or accessMap[departmentKey] ~= nil
end

function CBKCommsState.ResolveChannelAccessForMap(accessMap, departmentKey, channelKey)
    return resolveChannelAccess(accessMap, departmentKey, channelKey)
end

local function buildDepartmentPayload(accessMap)
    local departments = {}

    for _, departmentKey in ipairs(CBKComms.Config.Departments.order) do
        local def = CBKCommsDepartments.GetDefinition(departmentKey)
        local cfg = CBKComms.DepartmentConfigs[departmentKey]
        local access = accessMap[departmentKey]
        local canViewThisDepartment = canViewDepartment(accessMap, departmentKey)
        local departmentAccess = resolveChannelAccess(accessMap, departmentKey, 'primary')

        if def and cfg and cfg.enabled and canViewThisDepartment then
            departments[departmentKey] = {
                key = departmentKey,
                label = def.label,
                shortLabel = def.shortLabel,
                color = def.color,
                authorized = departmentAccess ~= nil,
                tier = access and access.tier or 0,
                tierLabel = departmentAccess and departmentAccess.tierLabel or 'Unauthorized',
                memberLabel = departmentAccess and departmentAccess.memberLabel or '',
                accessMode = departmentAccess and departmentAccess.accessMode or 'none',
                channels = {}
            }
        end
    end
    return departments
end

function CBKCommsState.RefreshPlayer(src)
    local access = CBKCommsAccess.ResolveDepartmentAccess(src)
    local entry = CBKCommsState.players[src] or {}
    entry.access = access
    entry.departments = buildDepartmentPayload(access)
    entry.volume = entry.volume or CBKComms.Config.Radio.defaultVolume
    entry.radioOn = entry.radioOn ~= false
    CBKCommsState.players[src] = entry
    return entry
end

function CBKCommsState.RemovePlayer(src)
    CBKCommsState.players[src] = nil
end

function CBKCommsState.GetPlayer(src)
    return CBKCommsState.players[src]
end

function CBKCommsState.GetPlayerAccess(src)
    return CBKCommsState.players[src] and CBKCommsState.players[src].access or nil
end

function CBKCommsState.HasAnyAccess(src)
    local entry = CBKCommsState.players[src] or CBKCommsState.RefreshPlayer(src)
    return next(entry.access or {}) ~= nil
end

function CBKCommsState.ResolveChannelAccess(src, departmentKey, channelKey)
    local entry = CBKCommsState.players[src] or CBKCommsState.RefreshPlayer(src)
    return resolveChannelAccess(entry.access, departmentKey, channelKey)
end

function CBKCommsState.CanViewDepartment(src, departmentKey)
    local entry = CBKCommsState.players[src] or CBKCommsState.RefreshPlayer(src)
    return canViewDepartment(entry.access, departmentKey)
end

function CBKCommsState.BuildUiState(src)
    local entry = CBKCommsState.players[src] or CBKCommsState.RefreshPlayer(src)
    local channels = CBKCommsChannels.SerializeDepartmentChannels()
    local payload = {
        radioOn = entry.radioOn,
        volume = entry.volume,
        active = CBKComms.DeepCopy(CBKCommsChannels.GetMembership(src)),
        departments = CBKComms.DeepCopy(entry.departments),
        channels = channels
    }

    CBKCommsChannels.PopulateCounts(payload.channels)

    for departmentKey, dept in pairs(payload.departments) do
        dept.channels = payload.channels[departmentKey] or {}

        for channelKey, channel in pairs(dept.channels) do
            channel.canJoin = resolveChannelAccess(entry.access, departmentKey, channelKey) ~= nil
        end
    end

    for departmentKey, _ in pairs(payload.channels) do
        if payload.departments[departmentKey] == nil then
            payload.channels[departmentKey] = nil
        end
    end

    return payload
end

function CBKCommsState.SetVolume(src, value)
    local entry = CBKCommsState.players[src] or CBKCommsState.RefreshPlayer(src)
    entry.volume = value
end

function CBKCommsState.SetRadioPower(src, enabled)
    local entry = CBKCommsState.players[src] or CBKCommsState.RefreshPlayer(src)
    entry.radioOn = enabled == true
end
