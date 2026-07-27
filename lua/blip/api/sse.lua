local M = {}

function M.process(buffer, data, on_chunk)
    buffer = buffer .. data .. '\n'

    while true do
        local dbl = buffer:find('\n\n')
        if not dbl then break end

        local event = buffer:sub(1, dbl - 1)
        buffer = buffer:sub(dbl + 2)

        for line in event:gmatch('[^\r\n]+') do
            local payload = line:match('^data: (.*)$')
            if payload then
                if payload == '[DONE]' then return buffer, true end
                local ok, json = pcall(vim.fn.json_decode, payload)
                if ok and json.choices and json.choices[1] then
                    local delta = json.choices[1].delta or {}
                    local chunk = delta.content
                    if type(chunk) == 'string' then on_chunk(chunk) end
                end
            end
        end
    end
    return buffer, false
end

return M
