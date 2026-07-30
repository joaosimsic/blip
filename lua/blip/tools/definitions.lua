local M = {}

M.all = {
    {
        type = 'function',
        ['function'] = {
            name = 'list_directory',
            description = 'List files and directories at a relative path from project root. Directories are shown with a trailing "/". Use this to explore the filesystem and discover file locations.',
            parameters = {
                type = 'object',
                properties = {
                    path = { type = 'string', description = 'Relative directory path from project root (e.g. "lua/blip")' },
                },
                required = { 'path' },
            },
        },
    },
    {
        type = 'function',
        ['function'] = {
            name = 'search_code',
            description = 'Search the codebase using ripgrep. Returns matching file:line:content results with filesystem paths relative to project root. Use list_directory first if you need to explore the file structure.',
            parameters = {
                type = 'object',
                properties = {
                    query = { type = 'string', description = 'Search query (regex supported)' },
                    max_results = { type = 'number', description = 'Maximum number of results (default 15)' },
                    include = { type = 'string', description = "File glob filter (e.g. '*.rs', '*.{ts,tsx}')" },
                },
                required = { 'query' },
            },
        },
    },
    {
        type = 'function',
        ['function'] = {
            name = 'read_file_lines',
            description = 'Read specific lines from a file relative to project root. Defaults to max 5 lines. If the exact path fails, common Lua module path variants are tried automatically (e.g. "lua/foo.lua" -> "lua/foo/init.lua" and vice versa). Use paths as shown by list_directory or search_code results.',
            parameters = {
                type = 'object',
                properties = {
                    path = { type = 'string', description = 'Relative path from project root (use filesystem path, e.g. "lua/blip/agent/init.lua", not a Lua require path like "blip.agent")' },
                    start_line = { type = 'number', description = 'First line to read (1-indexed, default 1)' },
                    end_line = {
                        type = 'number',
                        description = 'Last line to read (inclusive, defaults to start_line + 4)',
                    },
                },
                required = { 'path' },
            },
        },
    },
}

return M
