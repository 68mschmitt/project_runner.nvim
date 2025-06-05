-- utils.lua
local M = {}

M.name_exists = function(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name then
            return true
        end
    end
    return false
end

M.is_valid_name = function(name, existing_entries)
    for _, entry in ipairs(existing_entries) do
        if entry.name == name then
            return false
        end
    end
    return true
end

M.find_project_by_name = function(projects, name)
    for _, project in ipairs(projects or {}) do
        if project.name == name then
            return project
        end
    end
    return nil
end

return M
