local display = require("blip.display")
local api = require("blip.api")
local tools = require("blip.tools")

local MAX_DEPTH = 8

local M = {}

---@param numbered_code string
---@param input string
---@return BlipMessage[]
local function build_messages(numbered_code, input)
	local system = "You are a concise coding assistant with access to the codebase. "
		.. "You can use tools to search code and read files. "
		.. "Use tools to gather relevant context before answering code questions.\n\n"
		.. "When the user asks about code, search for relevant symbols, imports, definitions, and usages. "
		.. "Code lines are prefixed with their line number (L<number>:). "
		.. "Explain each line by referencing its number "
		.. "formatted as L<line_number>: <explanation>. "
		.. "DO NOT include the code line itself in the explanation. "
		.. "Skip trivial lines like empty lines, braces, and syntax-only lines unless the question asks about them. No preamble."

	local user = string.format("Code:\n```\n%s\n```\n\nQuestion: %s", numbered_code, input)

	return {
		{ role = "system", content = system },
		{ role = "user", content = user },
	}
end

---@param state BlipState
local function refresh_display(state)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
	display.show_tool_actions(state.bufnr, state.extmark_id, state.extmark_line, state.actions)
end

---@param text string
---@param state BlipState
local function add_action(text, state)
	table.insert(state.actions, "  " .. text)
	refresh_display(state)
end

---@param msg string
---@param state BlipState
local function show_error(msg, state)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
	display.show_response(state.bufnr, state.extmark_id, state.extmark_line, msg)
end

---@param content string
---@param state BlipState
local function show_final(content, state)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end

	local trimmed = vim.trim(content or "")
	if trimmed == "" then
		display.show_response(state.bufnr, state.extmark_id, state.extmark_line, "Empty response from API")
		return
	end

	if trimmed:find("L%d+:") then
		pcall(vim.api.nvim_buf_set_extmark, state.bufnr, display.ns_id, 0, 0, {
			id = state.extmark_id,
			virt_lines = {},
		})
	else
		vim.api.nvim_buf_clear_namespace(state.bufnr, display.ns_id, 0, -1)
		display.distribute_response(state.bufnr, state.extmark_id, state.start_0idx, state.extmark_line, trimmed)
	end
end

---@param tc BlipToolCall
---@return string
local function tool_preview(tc)
	local ok, args = pcall(vim.fn.json_decode, tc["function"].arguments)
	if not ok then args = {} end

	if tc["function"].name == "search_code" then
		return tc["function"].name .. '("' .. (args.query or "?") .. '")'
	elseif tc["function"].name == "read_file_lines" then
		local preview = tc["function"].name .. "(" .. (args.path or "?")
		if args.start_line then
			preview = preview .. ":" .. args.start_line
		end
		return preview .. ")"
	end
	return tc["function"].name .. "(...)"
end

---@param tool_calls BlipToolCall[]
---@param messages BlipMessage[]
---@param state BlipState
local function handle_tool_calls(tool_calls, messages, state)
	table.insert(messages, {
		role = "assistant",
		content = "",
		tool_calls = tool_calls,
	})

	for _, tc in ipairs(tool_calls) do
		add_action(tool_preview(tc), state)

		local ok, args = pcall(vim.fn.json_decode, tc["function"].arguments)
		if not ok then args = {} end

		local result = tools.execute(tc["function"].name, args, state.project_root)

		vim.notify(string.format("tool %s: %d chars", tc["function"].name, #result), vim.log.levels.INFO)

		table.insert(messages, {
			role = "tool",
			tool_call_id = tc.id,
			content = result,
		})
	end
end

---@param messages BlipMessage[]
---@param state BlipState
---@param depth integer
local function agent_round(messages, state, depth)
	if not vim.api.nvim_buf_is_valid(state.bufnr) then return end
	if depth > MAX_DEPTH then
		show_error("Reached maximum tool call depth", state)
		return
	end

	vim.notify(string.format("agent round %d: %d messages", depth + 1, #messages), vim.log.levels.INFO)

	api.chat(messages, tools.definitions, state.api_key,
		---@param message BlipMessage
		function(message)
			if message.tool_calls and #message.tool_calls > 0 then
				handle_tool_calls(message.tool_calls, messages, state)
				agent_round(messages, state, depth + 1)
				return
			end

			api.chat_stream(messages, state.api_key,
				---@param _ string
				---@param accumulated string
				function(_, accumulated)
					if not vim.api.nvim_buf_is_valid(state.bufnr) then return end

					local lines = vim.split(accumulated, "\n")
					local ends_with_nl = accumulated:sub(-1) == "\n"
					local complete_count = #lines - 1

					for i = state.stream_line_count + 1, complete_count do
						local line = lines[i]
						local ref, rest = display.parse_line_tag(line)
						if ref then
							local linenr = ref - 1
							if linenr >= state.start_0idx and linenr <= state.extmark_line
							   and not state.stream_placed_lines[linenr] then
								if linenr == state.stream_active_linenr and state.stream_active_extmark_id then
									pcall(vim.api.nvim_buf_del_extmark, state.bufnr, display.ns_id, state.stream_active_extmark_id)
									state.stream_active_linenr = nil
									state.stream_active_extmark_id = nil
								end
								display.place_line_ref(state.bufnr, linenr, rest)
								state.stream_placed_lines[linenr] = true
							end
						end
					end

					state.stream_line_count = complete_count

					if not ends_with_nl then
						local last_line = lines[#lines]
						local ref, rest = display.parse_line_tag(last_line)
						if ref then
							local linenr = ref - 1
							if linenr >= state.start_0idx and linenr <= state.extmark_line then
								if linenr ~= state.stream_active_linenr then
									state.stream_active_linenr = linenr
									state.stream_active_extmark_id = nil
									pcall(vim.api.nvim_buf_set_extmark, state.bufnr, display.ns_id, 0, 0, {
										id = state.extmark_id,
										virt_lines = {},
									})
								end
								state.stream_active_extmark_id = display.update_line_ref(
									state.bufnr, linenr, rest, state.stream_active_extmark_id
								)
							end
						else
							if state.stream_active_linenr then
								state.stream_active_linenr = nil
								state.stream_active_extmark_id = nil
							end
							display.show_incomplete_line(state.bufnr, state.extmark_id, state.extmark_line, last_line)
						end
					elseif state.stream_active_linenr then
						state.stream_active_linenr = nil
						state.stream_active_extmark_id = nil
					end
				end,
				---@param full_content string
				function(full_content)
					show_final(full_content, state)
				end,
				---@param err string
				function(err)
					show_error(err, state)
				end
			)
		end,
		---@param err string
		function(err)
			show_error(err, state)
		end
	)
end

---@class BlipRunOpts
---@field bufnr integer
---@field extmark_line integer
---@field start_line integer
---@field end_line integer
---@field numbered_code string
---@field input string
---@field api_key? string

---@param opts BlipRunOpts
function M.run(opts)
	local bufnr = opts.bufnr
	local extmark_line = opts.extmark_line
	local start_line = opts.start_line
	local end_line = opts.end_line
	local numbered_code = opts.numbered_code
	local input = opts.input
	local project_root = tools.find_project_root(bufnr)
	local api_key = opts.api_key or vim.env.OPENAI_API_KEY

	if not api_key then
		vim.notify("Blip: Set OPENAI_API_KEY", vim.log.levels.ERROR)
		return
	end

	local _, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, display.ns_id, extmark_line, 0, {
		virt_lines = { { { display.get_indent(bufnr, extmark_line) .. "Thinking", "Comment" } } },
	})
	if not extmark_id then return end

	---@type BlipState
	local state = {
		bufnr = bufnr,
		extmark_id = extmark_id,
		extmark_line = extmark_line,
		start_0idx = start_line - 1,
		api_key = api_key,
		project_root = project_root,
		actions = {},
		stream_line_count = 0,
		stream_placed_lines = {},
		stream_active_linenr = nil,
		stream_active_extmark_id = nil,
	}

	local messages = build_messages(numbered_code, input)
	agent_round(messages, state, 0)
end

return M
