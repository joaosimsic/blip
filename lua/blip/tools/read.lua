local log = require('blip.log')

local M = {}

local function try_read(full_path)
    local ok, lines = pcall(vim.fn.readfile, full_path)
    if ok and type(lines) == 'table' and #lines > 0 then
        return lines
    end
    return nil
end

local function resolve_path(path, project_root)
    local full_path = project_root .. '/' .. path:gsub('^%.?/+', '')

    local lines = try_read(full_path)
    if lines then return full_path, lines end

    local attempts = {}

    if path:match('%.lua$') then
        local alt = path:gsub('([^/]+)%.lua$', '%1/init.lua')
        if alt ~= path then
            table.insert(attempts, project_root .. '/' .. alt:gsub('^%.?/+', ''))
        end
    end

    if path:match('/init%.lua$') then
        local alt = path:gsub('/init%.lua$', '.lua')
        table.insert(attempts, project_root .. '/' .. alt:gsub('^%.?/+', ''))
    end

    if not path:match('%.[a-zA-Z]+$') then
        table.insert(attempts, full_path .. '.lua')
        table.insert(attempts, full_path .. '/init.lua')
    end

    for _, alt in ipairs(attempts) do
        lines = try_read(alt)
        if lines then
            log.debug('read_file_lines fallback: ' .. path .. ' -> ' .. alt:gsub('^.*/' .. vim.fn.fnamemodify(project_root, ':t') .. '/', ''))
            return alt, lines
        end
    end

    return nil, nil
end

function M.read_file_lines(path, start_line, end_line, project_root, max_read_lines)
    local full_path, lines = resolve_path(path, project_root)
    if not lines then return "Error: could not read file '" .. path .. "'" end

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
