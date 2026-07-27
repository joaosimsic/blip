local M = {}

M.all = {
    {
        type = 'function',
        ['function'] = {
            name = 'search_code',
            description = 'Search the codebase using ripgrep. Returns matching file:line:content results with paths relative to project root.',
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
            description = 'Read specific lines from a file relative to project root. Defaults to max 5 lines (lines start_line through start_line+4).',
            parameters = {
                type = 'object',
                properties = {
                    path = { type = 'string', description = 'Relative path from project root' },
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
