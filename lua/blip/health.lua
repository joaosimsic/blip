local M = {}

function M.check()
    local health = vim.health or require('health')

    health.start('blip')

    local ok, _ = pcall(require, 'plenary.curl')
    if ok then
        health.ok('plenary.nvim is installed')
    else
        health.error('plenary.nvim not found', 'Install it with your plugin manager (e.g. "nvim-lua/plenary.nvim")')
    end

    if vim.env.OPENAI_API_KEY then
        health.ok('OPENAI_API_KEY is set')
    else
        health.warn('OPENAI_API_KEY is not set', 'Set it in your environment or configure blip to pass it')
    end
end

return M
