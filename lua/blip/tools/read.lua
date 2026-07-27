local M = {}

function M.read_file_lines(path, start_line, end_line, project_root, max_read_lines)
    local full_path = path:gsub('^%.?/+', '')
    full_path = project_root .. '/' .. full_path

    local ok, lines = pcall(vim.fn.readfile, full_path)
    if not ok or type(lines) ~= 'table' then return "Error: could not read file '" .. path .. "'" end

    local default_range = (max_read_lines or 100) - 1
    local s = start_line or 1
    local e = end_line or math.min(s + default_range, #lines)
    s = math.max(1, s)
    e = math.min(e, #lines)

    local result = {}
    for i = s, e do
        table.insert(result, string.format('%d: %s', i, lines[i]))
    end
    return table.concat(result, '\n')
end

return M
