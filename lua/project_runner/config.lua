-- config.lua
local M = {}

M.defaultRunnersStructure = {
    projects = {},
    compounds = {},
}

M.defaults = {
    split_size = 10,
}

M.data_dir = vim.fn.stdpath("data") .. "/project_runner"
M.runner_file = M.data_dir .. "/runners.lua"

M.options = {}

M.setup = function(user_config)
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, user_config or {})
end

return M
