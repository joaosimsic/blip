local M = {}

function M.read_file_lines(path, start_line, end_line, project_root)
    local full_path = path
    if path:sub(1, 1) ~= '/' then full_path = project_root .. '/' .. path end

    local ok, lines = pcall(vim.fn.readfile, full_path)
    if not ok or type(lines) ~= 'table' then return "Error: could not read file '" .. path .. "'" end

    local s = start_line or 1
    local e = end_line or math.min(s + 4, #lines)
    s = math.max(1, s)
    e = math.min(e, #lines)

    local result = {}
    for i = s, e do
        table.insert(result, string.format('%d: %s', i, lines[i]))
    end
    return table.concat(result, '\n')
end

return M
