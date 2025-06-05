local config = require("project_runner.config")
local utils = require("project_runner.utils")
local executor = require("project_runner.executor")
local fileio = require("project_runner.file_io")
local runner_file = config.runner_file

local M = {}

M.add_entry_dialog = function()
    vim.ui.select({ "Project", "Compound" }, { prompt = "Add Project or Compound?" }, function(choice)
        if choice == "Project" then
            M.add_project_dialog()
        elseif choice == "Compound" then
            M.add_compound_dialog()
        end
    end)
end

M.add_project_dialog = function()
    local input = function(prompt, cb)
        vim.ui.input({ prompt = prompt }, function(res) cb(res) end)
    end

    local project = {}
    local runners = fileio.load()

    input("Project name: ", function(name)
        if not name or name == "" then return end
        if utils.name_exists(runners.projects, name) then
            vim.notify("A project with this name already exists!", vim.log.levels.ERROR)
            return
        end
        project.name = name

        input("Directory (absolute or ~): ", function(dir)
            if not dir or dir == "" then return end
            project.dir = dir

            input("Command to run: ", function(cmd)
                if not cmd or cmd == "" then return end
                project.command = cmd

                table.insert(runners.projects, project)
                fileio.save(runners)
                vim.notify("Added project '" .. project.name .. "' to project_runner.")
            end)
        end)
    end)
end

M.add_compound_dialog = function()
    local runners = fileio.load()
    local available_projects = {}
    for _, project in ipairs(runners.projects) do
        table.insert(available_projects, project.name)
    end
    local compound = { projects = {} }

    vim.ui.input({ prompt = "Compound name: " }, function(name)
        if not name or name == "" then return end
        if utils.name_exists(runners.compounds, name) then
            vim.notify("A compound with this name already exists!", vim.log.levels.ERROR)
            return
        end
        compound.name = name

        local function select_projects()
            if #available_projects == 0 then
                if #compound.projects > 0 then
                    table.insert(runners.compounds, compound)
                    fileio.save(runners)
                    vim.notify("Added compound '" .. compound.name .. "' to project_runner.")
                else
                    vim.notify("No projects added to compound.", vim.log.levels.WARN)
                end
                return
            end

            vim.ui.select(available_projects, { prompt = "Add project to compound (ESC to finish)" }, function(selected)
                if selected then
                    table.insert(compound.projects, selected)
                    for i, pname in ipairs(available_projects) do
                        if pname == selected then
                            table.remove(available_projects, i)
                            break
                        end
                    end
                    select_projects()
                else
                    if #compound.projects > 0 then
                        table.insert(runners.compounds, compound)
                        fileio.save(runners)
                        vim.notify("Added compound '" .. compound.name .. "' to project_runner.")
                    else
                        vim.notify("No projects added to compound.", vim.log.levels.WARN)
                    end
                end
            end)
        end

        select_projects()
    end)
end

M.select_runner_dialog = function()
    local runners = dofile(runner_file)
    local options = {}

    -- Add projects
    for _, project in ipairs(runners.projects or {}) do
        table.insert(options, { type = "Project", name = project.name, data = project })
    end
    -- Add compounds
    for _, compound in ipairs(runners.compounds or {}) do
        table.insert(options, { type = "Compound", name = compound.name, data = compound })
    end

    if #options == 0 then
        vim.notify("No projects or compounds to select.", vim.log.levels.INFO)
        return
    end

    vim.ui.select(options, {
        prompt = "Select a project or compound:",
        format_item = function(item)
            return string.format("[%s] %s", string.upper(item.type), item.name)
        end,
    }, function(choice)
        if choice then
            if choice.type == "Project" then
                executor.run_project_in_split(choice.data)
            elseif choice.type == "Compound" then
                -- Load all projects for this compound
                executor.run_compound_in_one_split(choice.data, runners.projects)
            end
        end
    end)
end

return M
