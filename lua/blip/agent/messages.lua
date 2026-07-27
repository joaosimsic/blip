local M = {}

function M.build(numbered_code, input)
    local system = 'You are a concise coding assistant with access to the codebase. '
        .. 'You can use tools to search code and read files. '
        .. 'Use tools to gather relevant context before answering code questions.\n\n'
        .. 'When the user asks about code, search for relevant symbols, imports, definitions, and usages. '
        .. 'Code lines are prefixed with their line number (L<number>:). '
        .. 'Explain each line by referencing its number '
        .. 'formatted as L<line_number>: <explanation>. '
        .. 'DO NOT include the code line itself in the explanation. '
        .. 'Skip trivial lines like empty lines, braces, and syntax-only lines unless the question asks about them. '
        .. 'No preamble.\n\n'
        .. 'When using read_file_lines, provide paths WITHOUT a leading "/" (relative to project root). '
        .. 'Search results show paths like "path/to/file.lua" - use that same format.\n\n'
        .. 'If a search returns no results, the symbol or file likely does not exist. '
        .. 'Do not repeatedly search for the same thing in different ways. '
        .. 'Answer with the information you already have.'

    local user = string.format('Code:\n```\n%s\n```\n\nQuestion: %s', numbered_code, input)

    return {
        { role = 'system', content = system },
        { role = 'user', content = user },
    }
end

return M
