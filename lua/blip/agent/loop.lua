local log = require('blip.log')
local display = require('blip.display')
local api = require('blip.api')
local tools = require('blip.tools')

local M = {}

local function refresh_display(state)
    if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
    display.show_tool_actions(state.bufnr, state.extmark_id, state.extmark_line, state.actions, state.reasoning)
end

local function add_action(text, state)
    table.insert(state.actions, '  ' .. text)
    if #state.actions > 5 then table.remove(state.actions, 1) end
    refresh_display(state)
end

local function show_error(msg, state)
    if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
    display.show_response(state.bufnr, state.extmark_id, state.extmark_line, msg)
end

local function show_final(content, state)
    if not vim.api.nvim_buf_is_valid(state.bufnr) then return end

    local trimmed = vim.trim(content or '')
    if trimmed == '' then
        display.show_response(state.bufnr, state.extmark_id, state.extmark_line, 'Empty response from API')
        return
    end

    if trimmed:find('L%d+:') then
        display.distribute_response(
            state.bufnr,
            state.extmark_id,
            state.start_0idx,
            state.extmark_line,
            trimmed,
            true,
            state.stream_placed_extmark_ids
        )
    end

    pcall(vim.api.nvim_buf_del_extmark, state.bufnr, display.ns_id, state.extmark_id)
end

local function tool_preview(tc)
    local ok, args = pcall(vim.fn.json_decode, tc['function'].arguments)
    if not ok then args = {} end

    if tc['function'].name == 'search_code' then
        return tc['function'].name .. '("' .. (args.query or '?') .. '")'
    elseif tc['function'].name == 'read_file_lines' then
        local preview = tc['function'].name .. '(' .. (args.path or '?')
        if args.start_line then preview = preview .. ':' .. args.start_line end
        return preview .. ')'
    end
    return tc['function'].name .. '(...)'
end

local function handle_tool_calls(tool_calls, messages, state)
    table.insert(messages, {
        role = 'assistant',
        content = '',
        tool_calls = tool_calls,
    })

    local had_repeat = false
    for _, tc in ipairs(tool_calls) do
        add_action(tool_preview(tc), state)
        log.debug('Tool call: ' .. vim.inspect(tc))

        local ok, args = pcall(vim.fn.json_decode, tc['function'].arguments)
        if not ok then args = {} end

        local sig = tc['function'].name .. '|' .. vim.fn.json_encode(args)
        if state.tool_call_history[sig] then
            had_repeat = true
        else
            state.tool_call_history[sig] = true
        end

        local result = tools.execute(tc['function'].name, args, state.project_root, state.max_read_lines)
        log.debug('Tool result (' .. #result .. ' chars): ' .. result:sub(1, 500))

        vim.notify(string.format('tool %s: %d chars', tc['function'].name, #result), vim.log.levels.INFO)

        table.insert(messages, {
            role = 'tool',
            tool_call_id = tc.id,
            content = result,
        })
    end

    if had_repeat then
        table.insert(messages, {
            role = 'user',
            content = '[System note: You just repeated one or more tool calls that already returned results. Use the information you already have and provide your answer instead of continuing to search.]',
        })
    end
end

local function clear_line_if_active(linenr, state)
    if linenr ~= state.stream_active_linenr or not state.stream_active_extmark_id then return end
    pcall(vim.api.nvim_buf_del_extmark, state.bufnr, display.ns_id, state.stream_active_extmark_id)
    state.stream_active_linenr = nil
    state.stream_active_extmark_id = nil
end

local function place_line_ref_if_needed(line, state)
    local ref, rest = display.parse_line_tag(line)
    if not ref then return end

    if vim.trim(rest):match('^|') then return end

    local linenr = ref - 1
    if linenr < state.start_0idx or linenr > state.extmark_line or state.stream_placed_lines[linenr] then return end

    clear_line_if_active(linenr, state)
    local id = display.place_line_ref(state.bufnr, linenr, rest)
    if id then state.stream_placed_extmark_ids[linenr] = id end
    state.stream_placed_lines[linenr] = true
end

local function clear_active_line(state)
    if not state.stream_active_linenr then return end
    state.stream_active_linenr = nil
    state.stream_active_extmark_id = nil
end

local function process_stream_delta(accumulated, state)
    if not vim.api.nvim_buf_is_valid(state.bufnr) then return end

    local lines = vim.split(accumulated, '\n')
    local ends_with_nl = accumulated:sub(-1) == '\n'
    local complete_count = #lines - 1

    for i = state.stream_line_count + 1, complete_count do
        place_line_ref_if_needed(lines[i], state)
    end

    state.stream_line_count = complete_count

    if not ends_with_nl then
        local ref, rest = display.parse_line_tag(lines[#lines])
        if ref and not vim.trim(rest):match('^|') then
            local linenr = ref - 1
            if linenr >= state.start_0idx and linenr <= state.extmark_line then
                if linenr ~= state.stream_active_linenr then
                    if state.stream_active_linenr and state.stream_active_extmark_id then
                        state.stream_placed_extmark_ids[state.stream_active_linenr] = state.stream_active_extmark_id
                    end
                    state.stream_active_linenr = linenr
                    state.stream_active_extmark_id = nil
                end
                state.stream_active_extmark_id =
                    display.update_line_ref(state.bufnr, linenr, rest, state.stream_active_extmark_id)
            end
        end
        return
    end
    clear_active_line(state)
end

function M.agent_round(messages, state, depth)
    if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
    if depth >= state.max_tool_calls then
        show_error('Reached maximum tool call depth', state)
        return
    end

    local msgs_str = vim.inspect(messages)
    if #msgs_str > 2000 then msgs_str = msgs_str:sub(1, 2000) .. '... (truncated)' end
    log.debug('Messages round ' .. (depth + 1) .. ' (' .. #messages .. '): ' .. msgs_str)

    vim.notify(string.format('agent round %d: %d messages', depth + 1, #messages), vim.log.levels.INFO)

    local round_tools = (depth == 0) and nil or tools.definitions
    api.chat(messages, round_tools, state.provider, state.api_key, function(message)
        if message.reasoning_content then
            state.reasoning = message.reasoning_content
            refresh_display(state)
        end

        if message.tool_calls and #message.tool_calls > 0 then
            handle_tool_calls(message.tool_calls, messages, state)
            M.agent_round(messages, state, depth + 1)
            return
        end

        api.chat_stream(
            messages,
            state.provider,
            state.api_key,
            function(_, accumulated) process_stream_delta(accumulated, state) end,
            function(full_content) show_final(full_content, state) end,
            function(err)
                log.debug('Stream failed, falling back to non-streaming: ' .. tostring(err))
                api.chat(
                    messages,
                    nil,
                    state.provider,
                    state.api_key,
                    function(message) show_final(message.content or '', state) end,
                    function(err2)
                        show_error('Stream failed (' .. err .. '); fallback also failed (' .. err2 .. ')', state)
                    end
                )
            end
        )
    end, function(err) show_error(err, state) end)
end

return M
