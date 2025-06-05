local config = require("project_runner.config")
local data_dir = config.data_dir
local runner_file = config.runner_file

local M = {}

M.ensure = function()
    if vim.fn.isdirectory(data_dir) == 0 then
        vim.fn.mkdir(data_dir, "p")
    end
    if vim.fn.filereadable(runner_file) == 0 then
        M.save(config.defaults)
    end
end

M.save = function(tbl)
    local file = io.open(runner_file, "w")
    file:write("return {\n")
    -- projects
    file:write("  projects = {\n")
    for _, project in ipairs(tbl.projects or {}) do
        file:write("    {")
        for k, v in pairs(project) do
            if type(v) == "string" then
                file:write(k .. '="' .. v .. '", ')
            else
                file:write(k .. "=" .. v .. ", ")
            end
        end
        file:write("},\n")
    end
    file:write("  },\n")
    -- compounds
    file:write("  compounds = {\n")
    for _, compound in ipairs(tbl.compounds or {}) do
        file:write('    {name="' .. compound.name .. '", projects={')
        for i, projname in ipairs(compound.projects or {}) do
            file:write('"' .. projname .. '"')
            if i < #compound.projects then file:write(",") end
        end
        file:write("}},\n")
    end
    file:write("  },\n}\n")
    file:close()
end

M.load = function()
    return dofile(runner_file)
end

return M
