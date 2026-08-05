local M = {}

local function process_event_line(line, on_chunk)
    local payload = line:match('^data: (.*)$')
    if not payload then return false end
    if payload == '[DONE]' then return true end
    local ok, json = pcall(vim.fn.json_decode, payload)
    if ok and json.choices and json.choices[1] and json.choices[1].delta then on_chunk(json.choices[1].delta) end
    return false
end

function M.process(buffer, data, on_chunk)
    buffer = buffer .. data .. '\n'
    local found_data_line = false

    while true do
        local dbl = buffer:find('\n\n')
        if not dbl then break end

        local event = buffer:sub(1, dbl - 1)
        buffer = buffer:sub(dbl + 2)

        for line in event:gmatch('[^\r\n]+') do
            if line:match('^data:') then found_data_line = true end
            if process_event_line(line, on_chunk) then return buffer, true, true end
        end
    end

    return buffer, false, found_data_line
end

return M
