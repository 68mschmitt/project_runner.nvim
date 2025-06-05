local utils = require("project_runner.utils")
local M = {}

M.open_single_split = function(height)
    vim.cmd("split")
    vim.cmd("resize " .. (height or 10))
    return vim.api.nvim_get_current_win()
end

M.open_terminal_in_win = function(win, project)
    vim.api.nvim_set_current_win(win)
    local shell = os.getenv("SHELL") or "sh"
    vim.cmd("enew")
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
        -- Send the command after a short delay
        vim.defer_fn(function()
            vim.api.nvim_chan_send(job_id, command .. "\n")
            -- After another brief delay, move cursor to the last line
            vim.defer_fn(function()
                local line_count = vim.api.nvim_buf_line_count(0)
                vim.api.nvim_win_set_cursor(0, {line_count, 0})
            end, 50)
        end, 100)
    end

    vim.cmd("startinsert")
end

M.run_project_in_split = function(project)
    local prev_win = vim.api.nvim_get_current_win()
    local split_win = M.open_single_split(10)
    M.open_terminal_in_win(split_win, project)
    vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(prev_win) then
            vim.api.nvim_set_current_win(prev_win)
        end
    end, 2000)
end

M.run_compound_in_one_split = function(compound, all_projects)
    local prev_win = vim.api.nvim_get_current_win()
    local split_win = M.open_single_split(10)
    for _, project_name in ipairs(compound.projects or {}) do
        local project = utils.find_project_by_name(all_projects, project_name)
        if project then
            M.open_terminal_in_win(split_win, project)
        else
            vim.notify("Project '" .. project_name .. "' not found for compound '" .. compound.name .. "'.", vim.log.levels.ERROR)
        end
    end
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
            local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
            if buftype == "terminal" then
                local ok, job_id = pcall(function()
                    return vim.api.nvim_buf_get_var(buf, "terminal_job_id")
                end)
                -- Kill the job if running
                if ok and job_id and job_id > 0 then
                    vim.fn.jobstop(job_id)
                    killed = killed + 1
                end
                -- Close all windows showing this buffer
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    if vim.api.nvim_win_get_buf(win) == buf then
                        vim.api.nvim_win_close(win, true)
                    end
                end
                -- Wipe the buffer itself
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
    end
    vim.notify("Killed " .. killed .. " project runner terminal job(s), closed splits, and wiped their buffers.")
end

return M
