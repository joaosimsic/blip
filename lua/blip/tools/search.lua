local M = {}

function M.search_code(query, max_results, include, project_root)
    local saved = vim.uv.cwd()
    vim.uv.chdir(project_root)
    local cmd = { 'rg', '--no-heading', '--line-number', '--color=never', '--smart-case' }
    if include then
        table.insert(cmd, '--glob')
        table.insert(cmd, include)
    end
    table.insert(cmd, query)
    table.insert(cmd, '.')

    local output = vim.fn.system(cmd)
    vim.uv.chdir(saved)
    if vim.v.shell_error ~= 0 then return 'No results found.' end

    local lines = vim.split(output, '\n')
    local results = {}
    for i = 1, math.min(#lines, max_results) do
        if lines[i] ~= '' then table.insert(results, lines[i]) end
    end
    return table.concat(results, '\n')
end

return M
