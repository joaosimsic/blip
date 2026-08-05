local display = require('blip.display')
local tools = require('blip.tools')
local messages = require('blip.agent.messages')
local loop = require('blip.agent.loop')

local M = {}

function M.run(opts)
    local bufnr = opts.bufnr
    local extmark_line = opts.extmark_line
    local start_line = opts.start_line
    local numbered_code = opts.numbered_code
    local input = opts.input
    local project_root = tools.find_project_root(bufnr)
    local provider = opts.provider
    local api_key = provider.api_key or (provider.api_key_env and vim.env[provider.api_key_env])

    if not api_key then
        local var = provider.api_key_env or 'not configured'
        vim.notify('Blip: No API key found (set ' .. var .. ' or pass api_key in setup)', vim.log.levels.ERROR)
        return
    end

    local _, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
        virt_lines = { { { display.get_indent(bufnr, extmark_line) .. 'Thinking', 'Comment' } } },
    })
    if not extmark_id then return end

    local cfg = require('blip.config').get() or {}

    local state = {
        bufnr = bufnr,
        extmark_id = extmark_id,
        extmark_line = extmark_line,
        start_0idx = start_line - 1,
        api_key = api_key,
        project_root = project_root,
        provider = provider,
        max_tool_calls = cfg.max_tool_calls or 16,
        max_read_lines = cfg.max_read_lines or 100,
        actions = {},
        reasoning = nil,
        tool_call_history = {},
        stream_line_count = 0,
        stream_placed_lines = {},
        stream_placed_extmark_ids = {},
        stream_active_linenr = nil,
        stream_active_extmark_id = nil,
        thinking_dots = 0,
        thinking_stopped = false,
        thinking_timer = vim.loop.new_timer(),
        has_padding_line = false,
    }

    if extmark_line >= vim.api.nvim_buf_line_count(bufnr) - 1 then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '' })
        state.has_padding_line = true
    end

    state.thinking_timer:start(
        500,
        500,
        vim.schedule_wrap(function()
            if state.thinking_stopped or not vim.api.nvim_buf_is_valid(bufnr) then return end
            state.thinking_dots = (state.thinking_dots % 3) + 1
            if state.reasoning or #state.actions > 0 then
                display.show_tool_actions(
                    bufnr,
                    extmark_id,
                    extmark_line,
                    state.actions,
                    state.reasoning,
                    state.thinking_dots
                )
            else
                local text = 'Thinking' .. string.rep('.', state.thinking_dots)
                pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
                    id = extmark_id,
                    virt_lines = { { { display.get_indent(bufnr, extmark_line) .. text, 'Comment' } } },
                })
            end
        end)
    )

    local msgs = messages.build(numbered_code, input)
    loop.agent_round(msgs, state, 0)
end

return M
