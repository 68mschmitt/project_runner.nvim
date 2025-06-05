local M = {}

-- Default config structure
M.defaultRunners = {
    projects = {},
    compounds = {},
}

-- Data dir for this plugin
local data_dir = vim.fn.stdpath("data") .. "/project_runner"
local config_file = data_dir .. "/runners.lua"

--- Checks if a name exists in a list of objects with a `name` property
---@param list table
---@param name string
---@return boolean
function M.name_exists(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name then
            return true
        end
    end
    return false
end

-- Helper: save config (supports projects and compounds)
function M.save_config(tbl)
    local file = io.open(config_file, "w")
    file:write("return {\n")
    -- Projects
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
    -- Compounds
    file:write("  compounds = {\n")
    for _, compound in ipairs(tbl.compounds or {}) do
        file:write('    {name="' .. compound.name .. '", projects={')
        for i, projname in ipairs(compound.projects or {}) do
            file:write('"' .. projname .. '"')
            if i < #compound.projects then file:write(",") end
        end
        file:write("}},\n")
    end
    file:write("  },\n")
    file:write("}\n")
    file:close()
end


-- Ensures a config file exists. Creates with defaults if not.
M.EnsureConfigFile = function()
    local file = io.open(config_file, "r")
    if file then
        file:close()
        return false -- Already exists
    else
        M.save_config(M.defaultRunners)
        return true -- Created new file
    end
end

-- Interactive dialog for a new entry (project or compound)
function M.add_entry_dialog()
    vim.ui.select({ "Project", "Compound" }, { prompt = "Add Project or Compound?" }, function(choice)
        if choice == "Project" then
            M.add_project_dialog()
        elseif choice == "Compound" then
            M.add_compound_dialog()
        end
    end)
end

function M.add_project_dialog()
    local input = function(prompt, cb)
        vim.ui.input({ prompt = prompt }, function(res)
            cb(res)
        end)
    end

    local project = {}

    input("Project name: ", function(name)
        if not name or name == "" then return end
        local runners = dofile(config_file)
        if M.name_exists(runners.projects, name) then
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

                M.EnsureConfigFile()
                table.insert(runners.projects, project)
                M.save_config(runners)
                vim.notify("Added project '" .. project.name .. "' to project_runner.")
            end)
        end)
    end)
end

function M.add_compound_dialog()
    local runners = dofile(config_file)
    local available_projects = {}
    for _, project in ipairs(runners.projects) do
        table.insert(available_projects, project.name)
    end

    local compound = { projects = {} }

    vim.ui.input({ prompt = "Compound name: " }, function(name)
        if not name or name == "" then return end
        if M.name_exists(runners.compounds, name) then
            vim.notify("A compound with this name already exists!", vim.log.levels.ERROR)
            return
        end
        compound.name = name

        local function select_projects()
            -- If none left, save immediately
            if #available_projects == 0 then
                if #compound.projects > 0 then
                    table.insert(runners.compounds, compound)
                    M.save_config(runners)
                    vim.notify("Added compound '" .. compound.name .. "' to project_runner.")
                else
                    vim.notify("No projects added to compound.", vim.log.levels.WARN)
                end
                return
            end

            vim.ui.select(available_projects, { prompt = "Add project to compound (ESC to finish)" }, function(selected)
                if selected then
                    table.insert(compound.projects, selected)
                    -- Remove selected project from the list
                    for i, pname in ipairs(available_projects) do
                        if pname == selected then
                            table.remove(available_projects, i)
                            break
                        end
                    end
                    select_projects()  -- allow more selections
                else
                    -- User pressed ESC or finished
                    if #compound.projects > 0 then
                        table.insert(runners.compounds, compound)
                        M.save_config(runners)
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

function M.select_runner_dialog()
    M.EnsureConfigFile()
    local runners = dofile(config_file)
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
                M.run_project_in_tab(choice.data)
            else
                vim.notify("Compound selected: " .. choice.name)
            end
        end
    end)
end

function M.run_project_in_tab(project)
    vim.cmd("tabnew")
    vim.cmd("terminal")
    local job_id = vim.b.terminal_job_id  -- set automatically for terminal buffers

    vim.cmd("startinsert")

    if project.dir and #project.dir > 0 then
        local cd_cmd = "cd " .. vim.fn.shellescape(project.dir) .. "\n"
        vim.api.nvim_chan_send(job_id, cd_cmd)
    end
    if project.command and #project.command > 0 then
        vim.api.nvim_chan_send(job_id, project.command .. "\n")
    end
end

vim.api.nvim_create_user_command("ProjectRunnerSelect", function()
    require("project_runner").select_runner_dialog()
end, {})

M.execute = function()
    vim.api.nvim_create_user_command("ProjectRunnerAdd", function()
        require("project_runner").add_entry_dialog()
    end, {})
end

-- Optionally: expose a setup function for lazy.nvim
M.setup = function()
    M.EnsureConfigFile()
    M.execute();
end

return M
