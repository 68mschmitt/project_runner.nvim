local M = {}
local termUtil = require("terminal-utilities")

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
                M.run_project_in_split(choice.data)
            elseif choice.type == "Compound" then
                -- Load all projects for this compound
                termUtil.run_compound_in_one_split(choice.data, runners.projects)
            end
        end
    end)
end

function M.run_project_in_split(project)
    -- 1. Save the current window handle
    local prev_win = vim.api.nvim_get_current_win()

    -- 2. Open horizontal split and resize
    vim.cmd("split")
    vim.cmd("resize 10")

    -- 3. Open terminal
    local shell = os.getenv("SHELL") or "sh"
    vim.cmd("terminal " .. shell)
    -- Get the terminal job id
    local job_id = vim.b.terminal_job_id

    -- 4. Build and send command
    local command = ""
    if project.dir and #project.dir > 0 and project.command and #project.command > 0 then
        command = "cd " .. vim.fn.shellescape(project.dir) .. " && " .. project.command
    elseif project.dir and #project.dir > 0 then
        command = "cd " .. vim.fn.shellescape(project.dir)
    elseif project.command and #project.command > 0 then
        command = project.command
    end

    if #command > 0 then
        vim.defer_fn(function()
            vim.api.nvim_chan_send(job_id, command .. "\n")
        end, 100) -- 100ms delay to ensure shell is ready
    end

    -- 5. Restore focus to the original window
    vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(prev_win) then
            vim.api.nvim_set_current_win(prev_win)
        end
    end, 150) -- Slightly longer delay than the command send
end

M.kill_all_project_runner_jobs = function()
    local killed = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
            if buftype == "terminal" then
                local ok, job_id = pcall(function() return vim.api.nvim_buf_get_var(buf, "terminal_job_id") end)
                if ok and job_id and job_id > 0 then
                    vim.fn.jobstop(job_id)
                    killed = killed + 1
                end
                -- Close (wipe) the buffer
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
    end
    vim.notify("Killed " .. killed .. " project runner terminal job(s) and wiped their buffers.")
end

vim.api.nvim_create_user_command("ProjectRunnerSelect", function()
    require("project_runner").select_runner_dialog()
end, {})

vim.api.nvim_create_user_command("ProjectRunnerKillAll", function()
    require("project_runner").kill_all_project_runner_jobs()
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
