local definitions = require('blip.tools.definitions')
local search = require('blip.tools.search')
local read = require('blip.tools.read')

local M = {}

M.definitions = definitions.all

function M.find_project_root(bufnr)
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    if buf_path == '' then return vim.fn.getcwd() end
    local dir = vim.fn.fnamemodify(buf_path, ':h')
    local root = vim.fn.system('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --show-toplevel 2>/dev/null')
    if vim.v.shell_error == 0 then return vim.trim(root) end
    return vim.fn.getcwd()
end

function M.execute(name, args, project_root, max_read_lines)
    if name == 'search_code' then
        return search.search_code(args.query, args.max_results or 15, args.include, project_root)
    elseif name == 'read_file_lines' then
        return read.read_file_lines(args.path, args.start_line, args.end_line, project_root, max_read_lines)
    end
    return "Error: unknown tool '" .. name .. "'"
end

return M
