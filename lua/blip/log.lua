local M = { debug_enabled = false }

function M.setup(opts) M.debug_enabled = opts and opts.debug == true end

function M.debug(msg)
    if not M.debug_enabled then return end
    vim.notify('[Blip] ' .. tostring(msg), vim.log.levels.DEBUG, { title = 'Blip' })
end

return M
