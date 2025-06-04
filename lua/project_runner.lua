--@class Config
local config = {
    autogenerate = false,
}

local M = {}

--@type Config
M.config = config

local Path = require("plenary.path")
local json = require("plenary.json")


-- Data dir for this plugin
local data_dir = vim.fn.stdpath("data") .. "\\project_runner"
local config_file = data_dir .. "\\projects.json"

-- Helper: ensure data dir and JSON exist
function M.ensure_config()
    if not Path:new(data_dir):exists() then
        Path:new(data_dir):mkdir({ parents = true })
    end
    if not Path:new(config_file):exists() then
        print(data_dir .. " : " .. config_file)
        json.write({ projects = {}, compounds = {} }, config_file)
    end
end

-- Helper: load projects config
function M.load_config()
    M.ensure_config()
    local ok, data = pcall(json.read, config_file)
    if not ok then
        vim.notify("Failed to read project_runner config: " .. data, vim.log.levels.ERROR)
        return { projects = {}, compounds = {} }
    end
    return data
end

-- Helper: save config
function M.save_config(tbl)
    M.ensure_config()
    json.write(tbl, config_file)
end

-- Interactive dialog for a new project
function M.add_project_dialog()
    local input = function(prompt, cb)
        vim.ui.input({ prompt = prompt }, function(res)
            cb(res)
        end)
    end

    local project = {}

    input("Project name: ", function(name)
        if not name or name == "" then return end
        project.name = name

        input("Directory (absolute or ~): ", function(dir)
            if not dir or dir == "" then return end
            project.dir = dir

            input("Command to run: ", function(cmd)
                if not cmd or cmd == "" then return end
                project.command = cmd

                -- Save
                local cfg = M.load_config()
                table.insert(cfg.projects, project)
                M.save_config(cfg)
                vim.notify("Added project '" .. project.name .. "' to project_runner.")
            end)
        end)
    end)
end

M.execute = function()
    -- Command to manually trigger the add-project dialog
    vim.api.nvim_create_user_command("ProjectRunnerAdd", function()
        require("project_runner").add_project_dialog()
    end, {})
end

-- Optionally: expose a setup function for lazy.nvim
M.setup = function(args)
    print("Hello from the project runner");
    M.config = vim.tbl_deep_extend("force", M.config, args or {});
    M.execute();
end

return M
