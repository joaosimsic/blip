local M = {}

local config = nil

function M.setup(opts)
    if not opts or not opts.provider then
        vim.notify("Blip: setup() requires a 'provider' table", vim.log.levels.ERROR)
        return
    end

    local p = opts.provider

    if not p.base_url or not p.model then
        vim.notify("Blip: provider must specify 'base_url' and 'model'", vim.log.levels.ERROR)
        return
    end

    if not p.api_key and not p.api_key_env then
        vim.notify("Blip: provider must specify 'api_key' or 'api_key_env'", vim.log.levels.ERROR)
        return
    end

    config = {
        provider = {
            base_url = p.base_url,
            model = p.model,
            max_tokens = p.max_tokens or 8192,
            api_key = p.api_key,
            api_key_env = p.api_key_env,
        },
    }
end

function M.get() return config end

return M
