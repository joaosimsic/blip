local display = require('blip.display')

local M = {}

function M.show_response(bufnr, extmark_id, extmark_line, answer)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local ok = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, display.ns_id, extmark_id, {})
    if not ok then return end

    local lines = vim.split(answer, '\n')
    local virt_lines = {}
    local indent = display.get_indent(bufnr, extmark_line)
    for _, line in ipairs(lines) do
        local wrapped = display.wrap_text(line, indent)
        for _, wl in ipairs(wrapped) do
            table.insert(virt_lines, wl)
        end
    end

    vim.api.nvim_buf_set_extmark(bufnr, display.ns_id, extmark_line, 0, {
        id = extmark_id,
        virt_lines = virt_lines,
    })
end

function M.show_incomplete_line(bufnr, extmark_id, extmark_line, text)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local indent = display.get_indent(bufnr, extmark_line)
    local virt_lines = display.wrap_text(text or '', indent)
    table.insert(virt_lines, { { indent .. '...', 'NonText' } })

    pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
        id = extmark_id,
        virt_lines = virt_lines,
    })
end

return M
