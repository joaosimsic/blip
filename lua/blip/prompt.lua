local display = require('blip.display')
local state = require('blip.state')

local M = {}

function M.start(opts)
    local bufnr = opts.bufnr
    local extmark_line = opts.extmark_line
    local on_submit = opts.on_submit
    opts.on_submit = nil

    vim.diagnostic.enable(false, { bufnr = bufnr })
    local lsp_clients = vim.lsp.get_clients({ bufnr = bufnr })
    for _, client in ipairs(lsp_clients) do
        vim.lsp.buf_detach_client(bufnr, client.id)
    end

    vim.api.nvim_buf_clear_namespace(bufnr, display.ns_id, 0, -1)

    local indent = display.get_indent(bufnr, extmark_line)

    local _, prompt_extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
        virt_lines = { { { indent .. 'Prompt: ', 'Comment' } } },
    })

    local input_line = extmark_line + 1
    vim.api.nvim_buf_set_lines(bufnr, input_line, input_line, false, { indent })
    vim.api.nvim_win_set_cursor(0, { input_line + 1, #indent })

    local submitting = false
    local canceling = false
    local prompt_group = vim.api.nvim_create_augroup('blip_prompt_' .. bufnr, { clear = true })

    local function restore_lsp()
        vim.diagnostic.enable(true, { bufnr = bufnr })
        for _, client in ipairs(lsp_clients) do
            pcall(vim.lsp.buf_attach_client, bufnr, client.id)
        end
    end

    local function cleanup()
        pcall(vim.api.nvim_buf_del_extmark, bufnr, display.ns_id, prompt_extmark_id)
        pcall(vim.api.nvim_buf_set_lines, bufnr, input_line, input_line + 1, false, {})
        pcall(vim.api.nvim_buf_del_keymap, bufnr, 'i', '<CR>')
        pcall(vim.api.nvim_buf_del_keymap, bufnr, 'i', '<C-c>')
        pcall(vim.api.nvim_del_augroup_by_id, prompt_group)
        restore_lsp()
        state.active_cleanup = nil
    end
    state.active_cleanup = cleanup

    local function cancel()
        if canceling then return end
        canceling = true
        vim.cmd('stopinsert')
        cleanup()
    end

    vim.api.nvim_create_autocmd('InsertLeave', {
        group = prompt_group,
        buffer = bufnr,
        callback = function()
            if submitting then
                submitting = false
                return
            end
            cancel()
        end,
    })

    vim.keymap.set('i', '<CR>', function()
        submitting = true
        vim.cmd('stopinsert')
        local lines = vim.api.nvim_buf_get_lines(bufnr, input_line, input_line + 1, false)
        local input = vim.trim(lines[1] or '')
        cleanup()

        if input == '' then return end

        on_submit(input)
    end, { buffer = bufnr, noremap = true, silent = true })

    vim.keymap.set('i', '<C-c>', cancel, { buffer = bufnr, noremap = true, silent = true })

    vim.cmd('startinsert')
end

return M
