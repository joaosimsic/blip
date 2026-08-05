local sse = require('blip.api.sse')

describe('sse', function()
    it('parses a single delta event', function()
        local deltas = {}
        local data = 'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n'
        local _, done = sse.process('', data, function(delta) table.insert(deltas, delta) end)
        assert.are.same({ { content = 'Hello' } }, deltas)
        assert.is_falsy(done)
    end)

    it('handles [DONE] signal', function()
        local data = 'data: [DONE]\n\n'
        local _, done = sse.process('', data, function() end)
        assert.is_true(done)
    end)

    it('accumulates partial chunks across multiple calls', function()
        local deltas = {}
        local buffer = ''
        buffer = sse.process(
            buffer,
            'data: {"choices":[{"delta":{"content":"Hello"}}]}',
            function(delta) table.insert(deltas, delta) end
        )
        assert.are.same({}, deltas)
        sse.process(buffer, '\n\n', function(delta) table.insert(deltas, delta) end)
        assert.are.same({ { content = 'Hello' } }, deltas)
    end)

    it('handles multiple events in one buffer', function()
        local deltas = {}
        local data = 'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n'
            .. 'data: {"choices":[{"delta":{"content":" World"}}]}\n\n'
        local _, done = sse.process('', data, function(delta) table.insert(deltas, delta) end)
        assert.are.same({ { content = 'Hello' }, { content = ' World' } }, deltas)
        assert.is_falsy(done)
    end)

    it('ignores non-data lines', function()
        local deltas = {}
        local data = ':comment\n\ndata: {"choices":[{"delta":{"content":"x"}}]}\n\n'
        local _, done = sse.process('', data, function(delta) table.insert(deltas, delta) end)
        assert.are.same({ { content = 'x' } }, deltas)
        assert.is_falsy(done)
    end)

    it('handles empty delta object', function()
        local deltas = {}
        local data = 'data: {"choices":[{"delta":{}}]}\n\n'
        local _, done = sse.process('', data, function(delta) table.insert(deltas, delta) end)
        assert.are.same({ {} }, deltas)
        assert.is_falsy(done)
    end)

    it('handles null delta content', function()
        local deltas = {}
        local data = 'data: {"choices":[{"delta":{"content":null}}]}\n\n'
        local _, done = sse.process('', data, function(delta) table.insert(deltas, delta) end)
        assert.equals(1, #deltas)
        assert.equals(vim.NIL, deltas[1].content)
        assert.is_falsy(done)
    end)
end)
