package.loaded['blip.display'] = {
    ns_id = 1,
    _last_bufnr = nil,
    _last_refs = nil,
    get_indent = function() return '' end,
    wrap_text = function() return {} end,
}
local refs = require('blip.display.refs')

describe('refs.parse_line_tag', function()
    it('extracts line number from L<N>: tag', function()
        local ref, rest = refs.parse_line_tag('L5: hello world')
        assert.equals(5, ref)
        assert.equals('hello world', rest)
    end)

    it('extracts line number from L<N>-L<M>: tag', function()
        local ref, rest = refs.parse_line_tag('L3-L5: range text')
        assert.equals(3, ref)
        assert.equals('range text', rest)
    end)

    it('extracts line number from L<N>–L<M>: with en-dash', function()
        local ref, rest = refs.parse_line_tag('L10–L12: en dash')
        assert.equals(10, ref)
        assert.equals('en dash', rest)
    end)

    it('extracts line number from L<N>—L<M>: with em-dash', function()
        local ref, rest = refs.parse_line_tag('L10—L12: em dash')
        assert.equals(10, ref)
        assert.equals('em dash', rest)
    end)

    it('returns nil for lines without tags', function()
        local ref, rest = refs.parse_line_tag('just some comment')
        assert.is_nil(ref)
        assert.is_nil(rest)
    end)

    it('returns nil for empty string', function()
        local ref, rest = refs.parse_line_tag('')
        assert.is_nil(ref)
        assert.is_nil(rest)
    end)

    it('handles tag with no rest text', function()
        local ref, rest = refs.parse_line_tag('L42:')
        assert.equals(42, ref)
        assert.equals('', rest)
    end)
end)
