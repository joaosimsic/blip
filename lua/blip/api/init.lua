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

    vim.notify(string.format('chat: %d messages, tools=%s', #messages, tostring(tools ~= nil)), vim.log.levels.INFO)

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

function M.chat_stream(messages, provider, api_key, on_delta, on_complete, on_error)
    local curl = require('plenary.curl')

    local json_body = vim.fn.json_encode({
        model = provider.model,
        messages = messages,
        max_tokens = provider.max_tokens,
        stream = true,
    })
    log.debug('Request body (stream): ' .. json_body)

    local sse_buffer = ''
    local accumulated = ''
    local completed = false
    local first_chunk_logged = false
    local total_bytes = 0
    local seen_valid_sse = false

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
        sse_buffer, done, found_data_line = sse.process(sse_buffer, data, function(chunk)
            seen_valid_sse = true
            if not first_chunk_logged then
                log.debug('First stream chunk: ' .. tostring(chunk))
                first_chunk_logged = true
            end
            accumulated = accumulated .. chunk
            on_delta(chunk, accumulated)
        end)
        if found_data_line then seen_valid_sse = true end

        if done then
            completed = true
            on_complete(accumulated)
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
            on_complete(accumulated)
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
