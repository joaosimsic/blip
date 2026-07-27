local sse = require('blip.api.sse')

describe('sse', function()
    it('parses a single delta event', function()
        local chunks = {}
        local data = 'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n'
        local buffer, done = sse.process('', data, function(chunk)
            table.insert(chunks, chunk)
        end)
        assert.are.same({ 'Hello' }, chunks)
        assert.is_falsy(done)
    end)

    it('handles [DONE] signal', function()
        local data = 'data: [DONE]\n\n'
        local buffer, done = sse.process('', data, function() end)
        assert.is_true(done)
    end)

    it('accumulates partial chunks across multiple calls', function()
        local chunks = {}
        local buffer = ''
        buffer = sse.process(buffer, 'data: {"choices":[{"delta":{"content":"Hello"}}]}', function(chunk)
            table.insert(chunks, chunk)
        end)
        assert.are.same({}, chunks)
        buffer = sse.process(buffer, '\n\n', function(chunk)
            table.insert(chunks, chunk)
        end)
        assert.are.same({ 'Hello' }, chunks)
    end)

    it('handles multiple events in one buffer', function()
        local chunks = {}
        local data = 'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\ndata: {"choices":[{"delta":{"content":" World"}}]}\n\n'
        local buffer, done = sse.process('', data, function(chunk)
            table.insert(chunks, chunk)
        end)
        assert.are.same({ 'Hello', ' World' }, chunks)
        assert.is_falsy(done)
    end)

    it('ignores non-data lines', function()
        local chunks = {}
        local data = ':comment\n\ndata: {"choices":[{"delta":{"content":"x"}}]}\n\n'
        local buffer, done = sse.process('', data, function(chunk)
            table.insert(chunks, chunk)
        end)
        assert.are.same({ 'x' }, chunks)
        assert.is_falsy(done)
    end)

    it('handles empty delta content', function()
        local chunks = {}
        local data = 'data: {"choices":[{"delta":{}}]}\n\n'
        local buffer, done = sse.process('', data, function(chunk)
            table.insert(chunks, chunk)
        end)
        assert.are.same({}, chunks)
        assert.is_falsy(done)
    end)

    it('handles null delta content', function()
        local chunks = {}
        local data = 'data: {"choices":[{"delta":{"content":null}}]}\n\n'
        local buffer, done = sse.process('', data, function(chunk)
            table.insert(chunks, chunk)
        end)
        assert.are.same({}, chunks)
        assert.is_falsy(done)
    end)
end)
