local M = {}
-- Open a horizontal split once and return its window id
M.open_single_split = function(height)
    vim.cmd("split")
    vim.cmd("resize " .. (height or 10))
    return vim.api.nvim_get_current_win()
end

-- Create a terminal buffer in the specified window and run the command
M.open_terminal_in_win = function(win, project)
    vim.api.nvim_set_current_win(win)
    local shell = os.getenv("SHELL") or "sh"
    vim.cmd("enew") -- New empty buffer
    vim.cmd("terminal " .. shell)
    local job_id = vim.b.terminal_job_id

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
            -- Move cursor to the last line to enable auto-scroll
            vim.api.nvim_win_set_cursor(0, {vim.api.nvim_buf_line_count(0), 0})
        end, 100)
    end
    vim.cmd("startinsert")
end

M.find_project_by_name = function(projects, name)
    for _, project in ipairs(projects or {}) do
        if project.name == name then
            return project
        end
    end
    return nil
end

M.run_compound_in_one_split = function(compound, all_projects)
    -- Save the current window to restore focus later
    local prev_win = vim.api.nvim_get_current_win()

    -- 1. Open a single split, get its window id
    local split_win = M.open_single_split(10)

    -- 2. For each project in compound, open a terminal buffer in that split
    for idx, project_name in ipairs(compound.projects or {}) do
        local project = M.find_project_by_name(all_projects, project_name)
        if project then
            M.open_terminal_in_win(split_win, project)
        else
            vim.notify("Project '" .. project_name .. "' not found for compound '" .. compound.name .. "'.", vim.log.levels.ERROR)
        end
    end

    -- 3. Restore focus
    vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(prev_win) then
            vim.api.nvim_set_current_win(prev_win)
        end
    end, 200)
end

M.kill_all_project_runner_jobs = function()
    local killed = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            -- New API: Get 'buftype' option from the buffer
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
            if buftype == "terminal" then
                local ok, job_id = pcall(function() return vim.api.nvim_buf_get_var(buf, "terminal_job_id") end)
                if ok and job_id and job_id > 0 then
                    vim.fn.jobstop(job_id)
                    killed = killed + 1
                end
            end
        end
    end
    vim.notify("Killed " .. killed .. " project runner terminal job(s).")
end

return M
