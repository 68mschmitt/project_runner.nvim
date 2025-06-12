-- config.lua
local M = {}

M.defaultRunnersStructure = {
    projects = {},
    compounds = {},
}

M.defaults = {
    split_size = 10,
    window_switch_timeout = 200,
}

M.data_dir = vim.fn.stdpath("data") .. "/project_runner"
M.runner_file = M.data_dir .. "/runners.lua"

M.options = {
    split_size = M.defaults.split_size,
    window_switch_timeout = M.window_switch_timeout,
}

M.setup = function(user_config)
    M.options = vim.tbl_deep_extend("force", M.options, user_config or {})
end

return M
