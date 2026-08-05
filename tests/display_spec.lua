local display

describe('display', function()
    before_each(function()
        package.loaded['blip.display'] = nil
        package.loaded['blip.display.virtual_text'] = nil
        package.loaded['blip.display.refs'] = nil
        package.loaded['blip.display.actions'] = nil
        vim.fn.winwidth = function() return 80 end
        vim.fn.getwininfo = function() return { { textoff = 2 } } end
        display = require('blip.display')
    end)

    after_each(function()
        vim.fn.winwidth = nil
        vim.fn.getwininfo = nil
    end)

    describe('wrap_text', function()
        it('returns empty for empty string', function() assert.are.same({}, display.wrap_text('', '')) end)

        it('returns empty for whitespace only', function() assert.are.same({}, display.wrap_text('   ', '')) end)

        it('wraps short text in a single chunk with Comment hl group', function()
            local result = display.wrap_text('hello', '')
            assert.equals(1, #result)
            assert.equals('hello', result[1][1][1])
            assert.equals('Comment', result[1][1][2])
        end)

        it('splits long text into multiple wrapped chunks', function()
            local text = string.rep('x', 200)
            local result = display.wrap_text(text, '')
            assert.is_true(#result >= 2, 'expected >= 2 virt_lines, got ' .. #result)
            for _, line in ipairs(result) do
                assert.is_true(#line[1][1] <= 78, 'chunk exceeds max_width: ' .. #line[1][1])
                assert.equals('Comment', line[1][2])
            end
        end)

        it('does not wrap table lines (| prefix)', function()
            local text = '| col1 | col2 | ' .. string.rep('x', 200) .. ' |'
            local result = display.wrap_text(text, '')
            assert.equals(1, #result)
            assert.is_true(#result[1][1][1] > 78, 'table line should not be wrapped, got length ' .. #result[1][1][1])
        end)

        it('reduces max_width when indent is provided', function()
            local text = string.rep('x', 80)
            local result = display.wrap_text(text, '    ')
            assert.is_true(#result >= 2, 'should wrap with 4-space indent')
            -- max_width = 80 - 2 - 4 = 74, plus the indent prefix
            for _, line in ipairs(result) do
                local full = line[1][1]
                assert.is_true(#full <= 78, 'chunk + indent exceeds window: ' .. #full)
                assert.equals('Comment', line[1][2])
            end
        end)

        it('handles nil indent (defaults to 0)', function()
            local result = display.wrap_text('hello', nil)
            assert.equals(1, #result)
            assert.equals('hello', result[1][1][1])
        end)
    end)

    describe('show_response', function()
        it('renders a long single-line response across multiple wrapped virt_lines', function()
            local bufnr = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
                '    function foo()',
                '        return 1 + 1',
                '    end',
            })

            local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, display.ns_id, 0, 0, {})

            local long_text = string.rep('explanation ', 20)
            display.show_response(bufnr, extmark_id, 0, long_text)

            local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, display.ns_id, 0, -1, { details = true })

            local found = false
            for _, em in ipairs(extmarks) do
                if em[1] == extmark_id then
                    found = true
                    local vl = em[4].virt_lines
                    assert.is_not_nil(vl)
                    assert.is_true(#vl >= 2, 'expected multiple virt_lines, got ' .. #vl)

                    for _, line in ipairs(vl) do
                        local full_text = ''
                        for _, s in ipairs(line) do
                            full_text = full_text .. s[1]
                            assert.equals('Comment', s[2])
                        end
                        assert.is_true(#full_text <= 80, 'virt_line too long: ' .. #full_text .. ' chars')
                    end
                end
            end
            assert.is_true(found, 'extmark ' .. extmark_id .. ' not found after show_response')

            vim.api.nvim_buf_delete(bufnr, { force = true })
        end)
    end)

    describe('distribute_response', function()
        it('renders L<N>: tagged lines next to source lines with proper wrapping', function()
            local bufnr = vim.api.nvim_create_buf(false, true)
            local lines = {}
            for i = 1, 5 do
                table.insert(lines, '    local var' .. i .. ' = ' .. i)
            end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

            local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, display.ns_id, 0, 0, {})

            local answer = 'L1: ' .. string.rep('x', 200) .. '\n' .. 'L3: ' .. string.rep('y', 150)
            display.distribute_response(bufnr, extmark_id, 0, 4, answer, false, {})

            local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, display.ns_id, 0, -1, { details = true })

            local found = { [0] = false, [2] = false }
            for _, em in ipairs(extmarks) do
                local row = em[2]
                local vl = em[4].virt_lines
                if row == 0 then
                    found[0] = true
                    assert.is_not_nil(vl)
                    for _, line in ipairs(vl) do
                        local full_text = ''
                        for _, seg in ipairs(line) do
                            full_text = full_text .. seg[1]
                        end
                        assert.is_true(#full_text <= 80, 'virt_line on row 0 too long: ' .. #full_text)
                    end
                elseif row == 2 then
                    found[2] = true
                    assert.is_not_nil(vl)
                    for _, line in ipairs(vl) do
                        local full_text = ''
                        for _, seg in ipairs(line) do
                            full_text = full_text .. seg[1]
                        end
                        assert.is_true(#full_text <= 80, 'virt_line on row 2 too long: ' .. #full_text)
                    end
                end
            end
            assert.is_true(found[0], 'extmark for line 1 (row 0) not found')
            assert.is_true(found[2], 'extmark for line 3 (row 2) not found')

            vim.api.nvim_buf_delete(bufnr, { force = true })
        end)
    end)
end)
