local M = {}

function M.list_directory(path, project_root)
    local full_path = path:gsub('^%.?/+', '')
    full_path = project_root .. '/' .. full_path

    local ok, entries = pcall(vim.fn.readdir, full_path)
    if not ok or type(entries) ~= 'table' then return "Error: could not list directory '" .. path .. "'" end

    table.sort(entries)
    local result = {}
    for _, entry in ipairs(entries) do
        local stat = vim.loop.fs_stat(full_path .. '/' .. entry)
        if stat and stat.type == 'directory' then
            table.insert(result, entry .. '/')
        else
            table.insert(result, entry)
        end
    end
    return table.concat(result, '\n')
end

return M
