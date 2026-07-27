local display = require('blip.display')

local M = {}

function M.show_tool_actions(bufnr, extmark_id, extmark_line, actions)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local indent = display.get_indent(bufnr, extmark_line)
    local virt_lines = {
        { { indent .. 'Thinking', 'Comment' } },
    }
    for _, a in ipairs(actions) do
        virt_lines[#virt_lines + 1] = { { indent .. '  ' .. a, 'NonText' } }
    end

    pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
        id = extmark_id,
        virt_lines = virt_lines,
    })
end

return M
