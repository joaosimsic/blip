local config = require('blip.config')

describe('config', function()
    before_each(function()
        package.loaded['blip.config'] = nil
        config = require('blip.config')
    end)

    it('returns nil before setup', function() assert.is_nil(config.get()) end)

    it('notifies error when setup is called without arguments', function()
        local msgs = {}
        vim.notify = function(msg, level) table.insert(msgs, { msg = msg, level = level }) end
        config.setup(nil)
        assert.equals(1, #msgs)
        assert.equals(vim.log.levels.ERROR, msgs[1].level)
    end)

    it('notifies error when provider has no base_url', function()
        local msgs = {}
        vim.notify = function(msg, level) table.insert(msgs, { msg = msg, level = level }) end
        config.setup({ provider = { model = 'gpt-4', api_key = 'sk-test' } })
        assert.equals(1, #msgs)
        assert.equals(vim.log.levels.ERROR, msgs[1].level)
    end)

    it('notifies error when provider has no model', function()
        local msgs = {}
        vim.notify = function(msg, level) table.insert(msgs, { msg = msg, level = level }) end
        config.setup({ provider = { base_url = 'https://example.com', api_key = 'sk-test' } })
        assert.equals(1, #msgs)
        assert.equals(vim.log.levels.ERROR, msgs[1].level)
    end)

    it('notifies error when provider has no api_key or api_key_env', function()
        local msgs = {}
        vim.notify = function(msg, level) table.insert(msgs, { msg = msg, level = level }) end
        config.setup({ provider = { base_url = 'https://example.com', model = 'gpt-4' } })
        assert.equals(1, #msgs)
        assert.equals(vim.log.levels.ERROR, msgs[1].level)
    end)

    it('sets default max_tokens when not provided', function()
        vim.notify = function() end
        config.setup({
            provider = {
                base_url = 'https://example.com',
                model = 'gpt-4',
                api_key = 'sk-test',
            },
        })
        local cfg = config.get()
        assert.is_not_nil(cfg)
        assert.equals(8192, cfg.provider.max_tokens)
    end)

    it('overrides max_tokens when provided', function()
        vim.notify = function() end
        config.setup({
            provider = {
                base_url = 'https://example.com',
                model = 'gpt-4',
                api_key = 'sk-test',
                max_tokens = 4096,
            },
        })
        local cfg = config.get()
        assert.equals(4096, cfg.provider.max_tokens)
    end)

    it('stores full config and returns it via get()', function()
        vim.notify = function() end
        local opts = {
            provider = {
                base_url = 'https://example.com',
                model = 'gpt-4',
                api_key = 'sk-test',
                api_key_env = nil,
                max_tokens = 4096,
            },
        }
        config.setup(opts)
        local cfg = config.get()
        assert.are.same(opts.provider.base_url, cfg.provider.base_url)
        assert.are.same(opts.provider.model, cfg.provider.model)
        assert.are.same(opts.provider.api_key, cfg.provider.api_key)
        assert.are.same(opts.provider.max_tokens, cfg.provider.max_tokens)
    end)
end)
