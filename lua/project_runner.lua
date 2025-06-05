local dialogs = require("project_runner.dialogs")
local executor = require("project_runner.executor")
local fileio = require("project_runner.file_io")

local M = {}

M.setup = function()
    fileio.ensure()
    vim.api.nvim_create_user_command("ProjectRunnerAdd", function() dialogs.add_entry_dialog() end, {})
    vim.api.nvim_create_user_command("ProjectRunnerSelect", function() dialogs.select_runner_dialog() end, {})
    vim.api.nvim_create_user_command("ProjectRunnerKillAll", function() executor.kill_all_project_runner_jobs() end, {})
end

return M
