local display = require('blip.display')

local M = {}

function M.show_tool_actions(bufnr, extmark_id, extmark_line, actions, reasoning, dots)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local indent = display.get_indent(bufnr, extmark_line)
    local header = 'Thinking' .. string.rep('.', dots or 0)
    local virt_lines = {
        { { indent .. header, 'Comment' } },
    }

    if reasoning then
        local lines = vim.split(reasoning, '\n')
        for _, line in ipairs(lines) do
            local wrapped = display.wrap_text(line, indent .. '  ')
            for _, wl in ipairs(wrapped) do
                table.insert(virt_lines, wl)
            end
        end
    end

    local max_display = 5
    local start = math.max(1, #actions - max_display + 1)
    for i = start, #actions do
        virt_lines[#virt_lines + 1] = { { indent .. '  ' .. actions[i], 'NonText' } }
    end

    pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
        id = extmark_id,
        virt_lines = virt_lines,
    })
end

return M
