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

    local sse_buffer = ''
    local accumulated = ''
    local completed = false

    local stream_handler = vim.schedule_wrap(function(err, data)
        if completed then return end
        if err then
            completed = true
            on_error('Stream error: ' .. tostring(err))
            return
        end
        if data == nil then return end

        local done
        sse_buffer, done = sse.process(sse_buffer, data, function(chunk)
            accumulated = accumulated .. chunk
            on_delta(chunk, accumulated)
        end)

        if done then
            completed = true
            on_complete(accumulated)
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
