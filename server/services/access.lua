CBKCommsAccess = {
    membersByDepartment = {}
}

local function buildAccess()
    CBKCommsAccess.membersByDepartment = {}

    for _, departmentKey in ipairs(CBKComms.Config.Departments.order) do
        local departmentConfig = CBKComms.DepartmentConfigs[departmentKey]
        if departmentConfig and departmentConfig.enabled then
            local members = {}
            for _, member in ipairs(departmentConfig.members or {}) do
                if type(member) == 'table' and type(member.tier) == 'number' and type(member.ids) == 'table' then
                    local identifiers = {}

                    for _, identifier in ipairs(member.ids) do
                        if type(identifier) == 'string' and identifier ~= '' then
                            identifiers[#identifiers + 1] = identifier
                        end
                    end

                    if #identifiers > 0 then
                        members[#members + 1] = {
                            tier = math.min(5, math.max(1, member.tier)),
                            label = member.label or 'Unnamed Member',
                            ids = identifiers
                        }
                    end
                end
            end

            CBKCommsAccess.membersByDepartment[departmentKey] = members
        end
    end
end

buildAccess()

function CBKCommsAccess.Reload()
    buildAccess()
end

function CBKCommsAccess.ResolveDepartmentAccess(src)
    local identifiers = CBKCommsSecurity.GetPlayerIdentifiersMap(src)
    local result = {}

    for _, departmentKey in ipairs(CBKComms.Config.Departments.order) do
        local members = CBKCommsAccess.membersByDepartment[departmentKey] or {}

        for _, entry in ipairs(members) do
            local matched = false

            for _, identifier in ipairs(entry.ids or {}) do
                if identifiers[identifier] then
                    matched = true
                    break
                end
            end

            if matched then
                local tiers = CBKComms.DepartmentConfigs[departmentKey].tiers or {}
                result[departmentKey] = {
                    department = departmentKey,
                    tier = entry.tier,
                    tierLabel = tiers[entry.tier] or (CBKComms.Config.Tiers[entry.tier] and CBKComms.Config.Tiers[entry.tier].label) or ('Tier ' .. entry.tier),
                    memberLabel = entry.label
                }
                break
            end
        end
    end

    return result
end
