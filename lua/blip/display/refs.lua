local display = require('blip.display')

local M = {}

local function wrap_and_add(list, text)
    local max_width = display.text_area_width()
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
    ref, rest = line:match('^L(%d+)%–L%d+:%s*(.*)$')
    if ref then return tonumber(ref), rest end
    ref, rest = line:match('^L(%d+)%–(%d+):%s*(.*)$')
    if ref then return tonumber(ref), rest end
    ref, rest = line:match('^L(%d+)%—L%d+:%s*(.*)$')
    if ref then return tonumber(ref), rest end
    ref, rest = line:match('^L(%d+)%—(%d+):%s*(.*)$')
    if ref then return tonumber(ref), rest end
    ref, rest = line:match('^L(%d+)%-L%d+:%s*(.*)$')
    if ref then return tonumber(ref), rest end
    ref, rest = line:match('^L(%d+)%-(%d+):%s*(.*)$')
    if ref then return tonumber(ref), rest end
    ref, rest = line:match('^%s*%*+L(%d+)%*+:%s*(.*)$')
    if ref then return tonumber(ref), rest end
    return nil, nil
end

function M.place_line_ref(bufnr, linenr, text)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local indent = display.get_indent(bufnr, linenr)
    local virt_lines = display.wrap_text(text, indent)
    if #virt_lines == 0 then return end

    local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, linenr, 0, {
        virt_lines = virt_lines,
    })
    if ok then return id end
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

local function is_table_line(text) return vim.trim(text):match('^|') ~= nil end

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
            line_entries[current_ref] = {}
            if not is_table_line(rest) then wrap_and_add(line_entries[current_ref], rest) end
        elseif has_refs then
            if current_ref and not is_table_line(line) then wrap_and_add(line_entries[current_ref], line) end
        else
            wrap_and_add(seq_lines, line)
        end
    end

    return line_entries, seq_lines, has_refs
end

local function is_trivial(text)
    local trimmed = vim.trim(text)
    return trimmed == '' or trimmed:match('^%d+$') ~= nil
end

local function store_refs_state(bufnr, line_entries)
    display._last_bufnr = bufnr
    display._last_refs = {}
    for linenr, entry in pairs(line_entries) do
        if #entry > 0 then
            local text = table.concat(entry, ' ')
            if not is_trivial(text) then display._last_refs[linenr] = text end
        end
    end
end

local function distribute_to_refs(bufnr, line_entries, extmark_ids)
    store_refs_state(bufnr, line_entries)

    local chunks = {}
    for linenr, entry in pairs(line_entries) do
        if #entry > 0 then
            local text = table.concat(entry, ' ')
            if is_trivial(text) then
                if extmark_ids and extmark_ids[linenr] then
                    pcall(vim.api.nvim_buf_del_extmark, bufnr, display.ns_id, extmark_ids[linenr])
                    extmark_ids[linenr] = nil
                end
            else
                local indent = display.get_indent(bufnr, linenr)
                local chunk = {}
                local text = table.concat(entry, ' ')
                local wrapped = display.wrap_text(text, indent)
                for _, wl in ipairs(wrapped) do
                    table.insert(chunk, wl)
                end
                chunks[linenr] = chunk
            end
        end
    end

    for linenr, chunk in pairs(chunks) do
        if #chunk > 0 then
            local opts = { virt_lines = chunk }
            if extmark_ids and extmark_ids[linenr] then opts.id = extmark_ids[linenr] end
            vim.api.nvim_buf_set_extmark(bufnr, display.ns_id, linenr, 0, opts)
        end
    end
end

local function distribute_sequential(bufnr, start_0idx, end_0idx, seq_lines, extmark_ids)
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
            local wrapped = display.wrap_text(seq_lines[idx], indent)
            for _, wl in ipairs(wrapped) do
                table.insert(chunk, wl)
            end
            table.insert(items, seq_lines[idx])
            idx = idx + 1
        end
        if #items > 0 then
            local text = table.concat(items, ' ')
            if not is_trivial(text) then display._last_refs[linenr] = text end
        end
        local opts = { virt_lines = chunk }
        if extmark_ids and extmark_ids[linenr] then opts.id = extmark_ids[linenr] end
        vim.api.nvim_buf_set_extmark(bufnr, display.ns_id, linenr, 0, opts)
    end
end

function M.distribute_response(bufnr, extmark_id, start_0idx, end_0idx, answer, keep_extmark, extmark_ids)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    if not keep_extmark then pcall(vim.api.nvim_buf_del_extmark, bufnr, display.ns_id, extmark_id) end

    local line_entries, seq_lines, has_refs = parse_response_lines(answer)

    if has_refs then
        if #seq_lines > 0 then
            if not line_entries[end_0idx] then line_entries[end_0idx] = {} end
            for _, item in ipairs(seq_lines) do
                table.insert(line_entries[end_0idx], item)
            end
        end
        distribute_to_refs(bufnr, line_entries, extmark_ids)
    else
        distribute_sequential(bufnr, start_0idx, end_0idx, seq_lines, extmark_ids)
    end
end

return M
