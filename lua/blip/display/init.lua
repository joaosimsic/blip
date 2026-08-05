local M = {}
package.loaded['blip.display'] = M

M.ns_id = vim.api.nvim_create_namespace('blip')
M._last_bufnr = nil
M._last_refs = nil

function M.get_indent(bufnr, linenr)
    local line = vim.api.nvim_buf_get_lines(bufnr, linenr, linenr + 1, false)[1]
    if not line then return '' end
    return line:match('^(%s*)') or ''
end

function M.wrap_text(text, indent)
    indent = indent or ''
    local virt_lines = {}
    local indent_len = #indent
    local max_width = math.max(20, vim.fn.winwidth(0) - 2 - indent_len)
    local trimmed = vim.trim(text)
    if trimmed == '' then return virt_lines end

    if trimmed:match('^|') then
        table.insert(virt_lines, { { indent .. trimmed, 'Comment' } })
        return virt_lines
    end

    while #trimmed > max_width do
        table.insert(virt_lines, { { indent .. trimmed:sub(1, max_width), 'Comment' } })
        trimmed = trimmed:sub(max_width + 1)
    end
    table.insert(virt_lines, { { indent .. trimmed, 'Comment' } })
    return virt_lines
end

function M.clear() vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1) end

local function comment_line(text)
    local cs = vim.bo.commentstring
    if cs and cs ~= '' and cs:find('%%s') then
        return cs:gsub('%%s', function() return text end)
    end
    return '-- ' .. text
end

local function line_has_comment(bufnr, linenr_0idx)
    local line = vim.api.nvim_buf_get_lines(bufnr, linenr_0idx, linenr_0idx + 1, false)[1]
    if not line then return false end
    local cs = vim.bo.commentstring
    local prefix = (cs and cs ~= '') and cs:match('^(.-)%s*%%s') or nil
    if not prefix then prefix = '--' end
    return line:find(vim.pesc(prefix), 1, true) ~= nil
end

function M.insert_explanations()
    local bufnr = vim.api.nvim_get_current_buf()
    if M._last_bufnr ~= bufnr or not M._last_refs then
        vim.notify('Blip: no explanations to insert', vim.log.levels.WARN)
        return
    end

    local refs = M._last_refs
    M._last_bufnr = nil
    M._last_refs = nil

    local linenrs = {}
    for linenr_0idx, _ in pairs(refs) do
        table.insert(linenrs, linenr_0idx)
    end
    table.sort(linenrs, function(a, b) return a > b end)

    local count = 0
    for _, linenr_0idx in ipairs(linenrs) do
        if not line_has_comment(bufnr, linenr_0idx) then
            local indent = M.get_indent(bufnr, linenr_0idx)
            local comment = indent .. comment_line(refs[linenr_0idx])
            vim.api.nvim_buf_set_lines(bufnr, linenr_0idx + 1, linenr_0idx + 1, false, { comment })
            count = count + 1
        end
    end
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
    vim.notify(string.format('Blip: inserted %d explanation line(s)', count))
end

local virtual_text = require('blip.display.virtual_text')
local refs = require('blip.display.refs')
local actions = require('blip.display.actions')

M.show_response = virtual_text.show_response
M.show_incomplete_line = virtual_text.show_incomplete_line
M.show_streaming_response = virtual_text.show_streaming_response
M.place_line_ref = refs.place_line_ref
M.update_line_ref = refs.update_line_ref
M.parse_line_tag = refs.parse_line_tag
M.distribute_response = refs.distribute_response
M.show_tool_actions = actions.show_tool_actions

return M
