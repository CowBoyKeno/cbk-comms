CBKCommsDepartments = {
    definitions = {},
    order = {}
}

function CBKCommsRegisterDepartment(definition)
    if type(definition) ~= 'table' or type(definition.key) ~= 'string' then
        error('cbk-comms department registration requires a table with a string key')
    end

    if CBKCommsDepartments.definitions[definition.key] then
        error(('cbk-comms duplicate department registration: %s'):format(definition.key))
    end

    local cfg = CBKComms.DepartmentConfigs[definition.key]
    if not cfg or not cfg.enabled then
        return
    end

    definition.label = definition.label or cfg.label or definition.key
    definition.shortLabel = definition.shortLabel or cfg.shortLabel or definition.key:upper()
    definition.color = definition.color or cfg.color or '#ffffff'

    CBKCommsDepartments.definitions[definition.key] = definition
    CBKCommsDepartments.order[#CBKCommsDepartments.order + 1] = definition.key
end

function CBKCommsDepartments.GetDefinition(departmentKey)
    return CBKCommsDepartments.definitions[departmentKey]
end

function CBKCommsDepartments.GetAll()
    return CBKCommsDepartments.definitions
end
