local M = {}

local function process_event_line(line, on_chunk)
    local payload = line:match('^data: (.*)$')
    if not payload then return false end
    if payload == '[DONE]' then return true end
    local ok, json = pcall(vim.fn.json_decode, payload)
    if ok and json.choices and json.choices[1] then
        local chunk = json.choices[1].delta and json.choices[1].delta.content
        if type(chunk) == 'string' then on_chunk(chunk) end
    end
    return false
end

function M.process(buffer, data, on_chunk)
    buffer = buffer .. data .. '\n'

    while true do
        local dbl = buffer:find('\n\n')
        if not dbl then break end

        local event = buffer:sub(1, dbl - 1)
        buffer = buffer:sub(dbl + 2)

        for line in event:gmatch('[^\r\n]+') do
            if process_event_line(line, on_chunk) then return buffer, true end
        end
    end

    return buffer, false
end

return M
