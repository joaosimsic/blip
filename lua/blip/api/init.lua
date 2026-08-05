local log = require('blip.log')
local sse = require('blip.api.sse')

local M = {}

local function build_headers(api_key)
    return {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. api_key,
    }
end

local function format_api_error(response)
    local msg = 'HTTP ' .. response.status
    local ok, res = pcall(vim.fn.json_decode, tostring(response.body))
    if ok and res and res.error then
        msg = msg
            .. ': '
            .. (type(res.error) == 'table' and (res.error.message or vim.inspect(res.error)) or tostring(res.error))
    end
    return msg
end

function M.chat(messages, tools, provider, api_key, on_success, on_error)
    local curl = require('plenary.curl')

    local body = {
        model = provider.model,
        messages = messages,
        max_tokens = provider.max_tokens,
        stream = false,
    }
    if tools then
        body.tools = tools
        body.tool_choice = 'auto'
    end

    local json_body = vim.fn.json_encode(body)
    log.debug('Request body: ' .. json_body)

    log.debug(string.format('chat: %d messages, tools=%s', #messages, tostring(tools ~= nil)))

    curl.request({
        url = provider.base_url .. '/chat/completions',
        method = 'POST',
        headers = build_headers(api_key),
        body = json_body,
        timeout = 30000,
        callback = vim.schedule_wrap(function(response)
            if response.exit ~= 0 then
                on_error('curl error (exit ' .. response.exit .. ')')
                return
            end

            log.debug('Response status: ' .. tostring(response.status))
            log.debug('Response body: ' .. tostring(response.body):sub(1, 2000))

            if response.status and response.status >= 400 then
                on_error(format_api_error(response))
                return
            end

            local ok, data = pcall(vim.fn.json_decode, response.body)
            if not ok or not data.choices or not data.choices[1] then
                on_error('Invalid API response')
                return
            end

            on_success(data.choices[1].message)
        end),
    })
end

function M.chat_stream(messages, tools, provider, api_key, on_delta, on_complete, on_error)
    local curl = require('plenary.curl')

    local body = {
        model = provider.model,
        messages = messages,
        max_tokens = provider.max_tokens,
        stream = true,
    }
    if tools then
        body.tools = tools
        body.tool_choice = 'auto'
    end

    local json_body = vim.fn.json_encode(body)
    log.debug('Request body (stream): ' .. json_body)

    local sse_buffer = ''
    local accumulated = ''
    local reasoning_content = ''
    local accumulated_tool_calls = {}
    local completed = false
    local first_chunk_logged = false
    local total_bytes = 0
    local seen_valid_sse = false

    local function build_message()
        local msg = { content = accumulated }
        if reasoning_content ~= '' then msg.reasoning_content = reasoning_content end
        if next(accumulated_tool_calls) then
            local tcs = {}
            local indices = vim.tbl_keys(accumulated_tool_calls)
            table.sort(indices)
            for _, idx in ipairs(indices) do
                table.insert(tcs, accumulated_tool_calls[idx])
            end
            msg.tool_calls = tcs
        end
        return msg
    end

    local stream_handler = vim.schedule_wrap(function(err, data)
        if completed then return end
        if err then
            completed = true
            on_error('Stream error: ' .. tostring(err))
            return
        end
        if data == nil then return end

        total_bytes = total_bytes + #data

        local done, found_data_line
        sse_buffer, done, found_data_line = sse.process(sse_buffer, data, function(delta)
            seen_valid_sse = true
            if not first_chunk_logged then
                log.debug('First stream delta: ' .. vim.inspect(delta))
                first_chunk_logged = true
            end

            if type(delta.content) == 'string' then
                accumulated = accumulated .. delta.content
                on_delta(delta.content, accumulated)
            end

            if type(delta.reasoning_content) == 'string' then
                reasoning_content = reasoning_content .. delta.reasoning_content
            end

            if delta.tool_calls then
                for _, tc in ipairs(delta.tool_calls) do
                    local idx = tc.index
                    if not accumulated_tool_calls[idx] then
                        accumulated_tool_calls[idx] = {
                            id = tc.id,
                            type = tc.type or 'function',
                            ['function'] = {
                                name = '',
                                arguments = '',
                            },
                        }
                    end
                    if tc['function'] then
                        if tc['function'].name then
                            accumulated_tool_calls[idx]['function'].name = accumulated_tool_calls[idx]['function'].name .. tc['function'].name
                        end
                        if tc['function'].arguments then
                            accumulated_tool_calls[idx]['function'].arguments = accumulated_tool_calls[idx]['function'].arguments .. tc['function'].arguments
                        end
                    end
                end
            end
        end)
        if found_data_line then seen_valid_sse = true end

        if done then
            completed = true
            on_complete(build_message())
            return
        end

        if not seen_valid_sse and total_bytes > 500 then
            completed = true
            on_error('Stream returned non-SSE data (possible API error or HTML response)')
        end
    end)

    local callback = vim.schedule_wrap(function(response)
        if completed then return end
        completed = true

        if response.exit ~= 0 then
            on_error('curl error (exit ' .. response.exit .. ')')
            return
        end
        if response.status and response.status >= 400 then
            on_error('HTTP ' .. response.status)
            return
        end
        if vim.trim(accumulated or '') ~= '' then
            log.debug('Stream complete (' .. #accumulated .. ' chars): ' .. accumulated:sub(1, 500))
            on_complete(build_message())
        else
            on_error('Empty response from API')
        end
    end)

    curl.request({
        url = provider.base_url .. '/chat/completions',
        method = 'POST',
        headers = build_headers(api_key),
        body = json_body,
        timeout = 30000,
        stream = stream_handler,
        callback = callback,
    })
end

return M
