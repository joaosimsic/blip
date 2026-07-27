local env = require("blip.env")

local M = {}

---@param bufnr integer
---@param mode SupportedModes
---@return integer, integer
function M.get_section(bufnr, mode)
	local start_line, end_line
	local buf_line_count = vim.api.nvim_buf_line_count(bufnr)

	if mode == "n" then
		local cursor = vim.api.nvim_win_get_cursor(0)
		start_line, end_line = cursor[1], cursor[1]
	elseif mode == "v" then
		vim.cmd("normal! \x1b")
		local s_start = vim.fn.getpos("'<")
		local s_end = vim.fn.getpos("'>")
		start_line, end_line = s_start[2], s_end[2]
	end

	start_line = math.max(1, math.min(start_line or 1, end_line or 1))
	end_line = math.min(end_line or 1, buf_line_count)

	return start_line, end_line
end

---@param lines string[]
---@param start_line integer
---@return string
function M.number_lines(lines, start_line)
	local result = {}
	for i, line in ipairs(lines) do
		table.insert(result, string.format("%3d | %s", start_line + i - 1, line))
	end
	return table.concat(result, "\n")
end

---@return string?, string?
function M.get_code_context()
	local mode = env.get_mode()
	if not mode then return nil, "Unsupported type" end

	local bufnr = vim.api.nvim_get_current_buf()
	local start_line, end_line = M.get_section(bufnr, mode)
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	return M.number_lines(buf_lines, start_line), nil
end

return M
