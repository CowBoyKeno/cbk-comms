CBKComms = CBKComms or {}

function CBKComms.ShallowCopy(tbl)
    local result = {}
    for key, value in pairs(tbl or {}) do
        result[key] = value
    end
    return result
end

function CBKComms.DeepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local out = {}
    for key, inner in pairs(value) do
        out[key] = CBKComms.DeepCopy(inner)
    end

    return out
end

function CBKComms.TableContains(list, needle)
    for i = 1, #list do
        if list[i] == needle then
            return true
        end
    end

    return false
end

function CBKComms.Trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:match('^%s*(.-)%s*$') or ''
end

function CBKComms.IsValidDepartmentKey(value)
    return type(value) == 'string' and CBKComms.DepartmentConfigs[value] ~= nil
end

function CBKComms.IsValidChannelKey(value)
    return type(value) == 'string' and CBKComms.Config.Departments.channels[value] ~= nil
end
