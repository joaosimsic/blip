local messages = require('blip.agent.messages')

describe('messages.build', function()
    it('returns two messages with system and user roles', function()
        local msgs = messages.build('1: print("hi")', 'what does this do?')
        assert.equals(2, #msgs)
        assert.equals('system', msgs[1].role)
        assert.equals('user', msgs[2].role)
    end)

    it('includes key instructions in the system prompt', function()
        local msgs = messages.build('1: x = 1', 'question')
        local content = msgs[1].content
        assert.matches('codebase', content)
        assert.matches('tools', content)
        assert.matches('line number', content)
        assert.matches('No preamble', content)
    end)

    it('formats the user message with code block and question', function()
        local code = '1: function foo()\n2:   return 42\n3: end'
        local question = 'explain this function'
        local msgs = messages.build(code, question)
        local content = msgs[2].content
        assert.matches('```', content)
        assert.is_true(content:find(code, 1, true) ~= nil)
        assert.is_true(content:find(question, 1, true) ~= nil)
    end)
end)
