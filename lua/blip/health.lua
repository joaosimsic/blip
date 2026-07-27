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

    local cfg = require('blip.config').get()
    if not cfg then
        health.warn('Not configured', 'Call require("blip").setup({provider = {...}}) in your config')
        return
    end

    local p = cfg.provider
    health.ok('Provider: ' .. p.base_url .. ' | Model: ' .. p.model)

    if p.api_key then
        health.ok('API key provided via config')
    elseif p.api_key_env and vim.env[p.api_key_env] then
        health.ok('API key found in $' .. p.api_key_env)
    elseif p.api_key_env then
        health.warn('$' .. p.api_key_env .. ' is not set', 'Set it in your environment or pass api_key in setup()')
    else
        health.warn('No API key configured', 'Set api_key or api_key_env in your setup()')
    end
end

return M
