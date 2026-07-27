local display = require('blip.display')

local M = {}

local function wrap_and_add(list, text)
    local max_width = math.max(20, vim.fn.winwidth(0) - 2)
    local trimmed = vim.trim(text)
    if trimmed == '' then return end
    while #trimmed > max_width do
        table.insert(list, trimmed:sub(1, max_width))
        trimmed = trimmed:sub(max_width + 1)
    end
    if #trimmed > 0 then table.insert(list, trimmed) end
end

function M.parse_line_tag(line)
    local ref, rest = line:match('^L(%d+):%s*(.*)$')
    if ref then return tonumber(ref), rest end
    ref, rest = line:match('^L(%d+)[%–%—%-]L%d+:%s*(.*)$')
    if ref then return tonumber(ref), rest end
    return nil, nil
end

function M.place_line_ref(bufnr, linenr, text)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local indent = display.get_indent(bufnr, linenr)
    local virt_lines = display.wrap_text(text, indent)
    if #virt_lines == 0 then return end

    pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, linenr, 0, {
        virt_lines = virt_lines,
    })
end

function M.update_line_ref(bufnr, linenr, text, extmark_id)
    if not vim.api.nvim_buf_is_valid(bufnr) then return nil end

    local indent = display.get_indent(bufnr, linenr)
    local virt_lines = display.wrap_text(text, indent)

    local opts = {}
    if extmark_id then opts.id = extmark_id end
    opts.virt_lines = virt_lines

    local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, linenr, 0, opts)
    if ok then return id end
    return nil
end

local function parse_response_lines(answer)
    local lines = vim.split(answer, '\n')
    local line_entries = {}
    local seq_lines = {}
    local has_refs = false
    local current_ref = nil

    for _, line in ipairs(lines) do
        local ref, rest = M.parse_line_tag(line)
        if ref then
            current_ref = ref - 1
            has_refs = true
            if not line_entries[current_ref] then line_entries[current_ref] = {} end
            wrap_and_add(line_entries[current_ref], rest)
        elseif has_refs then
            if current_ref then wrap_and_add(line_entries[current_ref], line) end
        else
            wrap_and_add(seq_lines, line)
        end
    end

    return line_entries, seq_lines, has_refs
end

local function store_refs_state(bufnr, line_entries, start_0idx, end_0idx)
    display._last_bufnr = bufnr
    display._last_refs = {}
    for linenr, entry in pairs(line_entries) do
        if linenr >= start_0idx and linenr <= end_0idx and #entry > 0 then
            display._last_refs[linenr] = table.concat(entry, ' ')
        end
    end
end

local function distribute_to_refs(bufnr, line_entries, start_0idx, end_0idx)
    store_refs_state(bufnr, line_entries, start_0idx, end_0idx)

    local chunks = {}
    for linenr, entry in pairs(line_entries) do
        if linenr >= start_0idx and linenr <= end_0idx and #entry > 0 then
            local indent = display.get_indent(bufnr, linenr)
            local chunk = {}
            for _, item in ipairs(entry) do
                table.insert(chunk, { { indent .. item, 'Comment' } })
            end
            chunks[linenr] = chunk
        end
    end

    for linenr, chunk in pairs(chunks) do
        if #chunk > 0 then
            vim.api.nvim_buf_set_extmark(bufnr, display.ns_id, linenr, 0, {
                virt_lines = chunk,
            })
        end
    end
end

local function distribute_sequential(bufnr, start_0idx, end_0idx, seq_lines)
    if #seq_lines == 0 then return end

    local num_source_lines = end_0idx - start_0idx + 1
    local lines_per_source = math.max(1, math.ceil(#seq_lines / num_source_lines))

    display._last_bufnr = bufnr
    display._last_refs = {}

    local idx = 1
    for linenr = start_0idx, end_0idx do
        local indent = display.get_indent(bufnr, linenr)
        local chunk = {}
        local items = {}
        for _ = 1, lines_per_source do
            if idx > #seq_lines then break end
            table.insert(chunk, { { indent .. seq_lines[idx], 'Comment' } })
            table.insert(items, seq_lines[idx])
            idx = idx + 1
        end
        if #items > 0 then display._last_refs[linenr] = table.concat(items, ' ') end
        vim.api.nvim_buf_set_extmark(bufnr, display.ns_id, linenr, 0, {
            virt_lines = chunk,
        })
    end
end

function M.distribute_response(bufnr, extmark_id, start_0idx, end_0idx, answer)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    pcall(vim.api.nvim_buf_del_extmark, bufnr, display.ns_id, extmark_id)

    local line_entries, seq_lines, has_refs = parse_response_lines(answer)

    if has_refs then
        distribute_to_refs(bufnr, line_entries, start_0idx, end_0idx)
        return
    end

    distribute_sequential(bufnr, start_0idx, end_0idx, seq_lines)
end

return M
