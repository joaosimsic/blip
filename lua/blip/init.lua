local display = require("blip.display")
local agent = require("blip.agent")
local editor = require("blip.editor")
local env = require("blip.env")
local state = require("blip.state")

local M = {}

function M.ask()
	local mode = env.get_mode()
	if not mode then
		vim.notify("Blip: unsupported mode", vim.log.levels.WARN)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local start_line, end_line = editor.get_section(bufnr, mode)
	local extmark_line = math.min(end_line - 1, math.max(0, line_count - 1))

	vim.diagnostic.enable(false, { bufnr = bufnr })
	local lsp_clients = vim.lsp.get_clients({ bufnr = bufnr })
	for _, client in ipairs(lsp_clients) do
		vim.lsp.buf_detach_client(bufnr, client.id)
	end

	vim.api.nvim_buf_clear_namespace(bufnr, display.ns_id, 0, -1)

	local _, prompt_extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
		virt_lines = { { { display.get_indent(bufnr, extmark_line) .. "Prompt: ", "Comment" } } },
	})

	local input_line = extmark_line + 1
	vim.api.nvim_buf_set_lines(bufnr, input_line, input_line, false, { "" })
	vim.api.nvim_win_set_cursor(0, { input_line + 1, 0 })

	local submitting = false
	local canceling = false
	local prompt_group = vim.api.nvim_create_augroup("blip_prompt_" .. bufnr, { clear = true })

	local function restore_lsp()
		vim.diagnostic.enable(true, { bufnr = bufnr })
		for _, client in ipairs(lsp_clients) do
			pcall(vim.lsp.buf_attach_client, bufnr, client.id)
		end
	end

	local function cleanup()
		pcall(vim.api.nvim_buf_del_extmark, bufnr, display.ns_id, prompt_extmark_id)
		pcall(vim.api.nvim_buf_set_lines, bufnr, input_line, input_line + 1, false, {})
		pcall(vim.api.nvim_buf_del_keymap, bufnr, "i", "<CR>")
		pcall(vim.api.nvim_buf_del_keymap, bufnr, "i", "<C-c>")
		pcall(vim.api.nvim_del_augroup_by_id, prompt_group)
		restore_lsp()
		state.active_cleanup = nil
	end
	state.active_cleanup = cleanup

	local function cancel()
		if canceling then return end
		canceling = true
		vim.cmd("stopinsert")
		cleanup()
	end

	vim.api.nvim_create_autocmd("InsertLeave", {
		group = prompt_group,
		buffer = bufnr,
		callback = function()
			if submitting then
				submitting = false
				return
			end
			cancel()
		end,
	})

	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	local numbered_code = editor.number_lines(buf_lines, start_line)

	vim.keymap.set("i", "<CR>", function()
		submitting = true
		vim.cmd("stopinsert")
		local lines = vim.api.nvim_buf_get_lines(bufnr, input_line, input_line + 1, false)
		local input = vim.trim(lines[1] or "")
		cleanup()

		if input == "" then return end

		agent.run({
			bufnr = bufnr,
			extmark_line = extmark_line,
			start_line = start_line,
			end_line = end_line,
			numbered_code = numbered_code,
			input = input,
		})
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.keymap.set("i", "<C-c>", cancel, { buffer = bufnr, noremap = true, silent = true })

	vim.cmd("startinsert")
end

function M.dismiss()
	if state.active_cleanup then
		state.active_cleanup()
	end
	display.clear()
end

function M.comment()
	display.insert_explanations()
end

package.loaded["blip"] = M
return M
