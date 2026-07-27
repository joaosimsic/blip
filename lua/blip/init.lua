local display = require('blip.display')
local agent = require('blip.agent')
local editor = require('blip.editor')
local env = require('blip.env')
local prompt = require('blip.prompt')
local state = require('blip.state')

local M = {}

function M.ask()
    local mode = env.get_mode()

    if not mode then
        vim.notify('Blip: unsupported mode', vim.log.levels.WARN)
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local start_line, end_line = editor.get_section(bufnr, mode)
    local extmark_line = math.min(end_line - 1, math.max(0, line_count - 1))

    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    local numbered_code = editor.number_lines(buf_lines, start_line)

    local opts = {
        bufnr = bufnr,
        extmark_line = extmark_line,
        start_line = start_line,
        end_line = end_line,
        numbered_code = numbered_code,
    }

    opts.on_submit = function(input)
        opts.input = input
        agent.run(opts)
    end

    prompt.start(opts)
end

function M.dismiss()
    if state.active_cleanup then state.active_cleanup() end
    display.clear()
end

function M.comment() display.insert_explanations() end

package.loaded['blip'] = M
return M
