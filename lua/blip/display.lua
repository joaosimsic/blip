local M = {}

---@type integer
local ns_id = vim.api.nvim_create_namespace("blip")
M.ns_id = ns_id

---@type integer?
M._last_bufnr = nil
---@type table<integer,string>?
M._last_refs = nil

---@param text string
---@return string
local function comment_line(text)
	local cs = vim.bo.commentstring
	if cs and cs ~= "" and cs:find("%%s") then
		return cs:gsub("%%s", text)
	end
	return "-- " .. text
end

---@param bufnr integer
---@param linenr integer
---@return string
function M.get_indent(bufnr, linenr)
	local line = vim.api.nvim_buf_get_lines(bufnr, linenr, linenr + 1, false)[1]
	if not line then
		return ""
	end
	return line:match("^(%s*)") or ""
end

---@param bufnr integer
---@param linenr integer
---@param text string
---@return table[]
local function wrap_text(bufnr, linenr, text)
	local virt_lines = {}
	local max_width = math.max(20, vim.fn.winwidth(0) - 2)
	local trimmed = vim.trim(text)
	if trimmed == "" then
		return virt_lines
	end
	while #trimmed > max_width do
		table.insert(virt_lines, { { M.get_indent(bufnr, linenr) .. trimmed:sub(1, max_width), "Comment" } })
		trimmed = trimmed:sub(max_width + 1)
	end
	table.insert(virt_lines, { { M.get_indent(bufnr, linenr) .. trimmed, "Comment" } })
	return virt_lines
end

---@param bufnr integer
---@param extmark_id integer
---@param extmark_line integer
---@param answer string
function M.show_response(bufnr, extmark_id, extmark_line, answer)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ok = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, ns_id, extmark_id, {})
	if not ok then
		return
	end

	local lines = vim.split(answer, "\n")
	local virt_lines = {}
	for _, line in ipairs(lines) do
		local wrapped = wrap_text(bufnr, extmark_line, line)
		for _, wl in ipairs(wrapped) do
			table.insert(virt_lines, wl)
		end
	end

	vim.api.nvim_buf_set_extmark(bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

---@param bufnr integer
---@param extmark_id integer
---@param extmark_line integer
---@param text string
function M.show_incomplete_line(bufnr, extmark_id, extmark_line, text)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local virt_lines = wrap_text(bufnr, extmark_line, text or "")
	table.insert(virt_lines, { { M.get_indent(bufnr, extmark_line) .. "...", "NonText" } })

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

---@param bufnr integer
---@param linenr integer
---@param text string
function M.place_line_ref(bufnr, linenr, text)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local virt_lines = wrap_text(bufnr, linenr, text)
	if #virt_lines == 0 then
		return
	end

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, linenr, 0, {
		virt_lines = virt_lines,
	})
end

---@param bufnr integer
---@param linenr integer
---@param text string
---@param extmark_id integer?
---@return integer?
function M.update_line_ref(bufnr, linenr, text, extmark_id)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	local virt_lines = wrap_text(bufnr, linenr, text)

	local opts = {}
	if extmark_id then
		opts.id = extmark_id
	end
	opts.virt_lines = virt_lines

	local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, linenr, 0, opts)
	if ok then
		return id
	end
	return nil
end

---@param bufnr integer
---@param extmark_id integer
---@param extmark_line integer
---@param actions string[]
function M.show_tool_actions(bufnr, extmark_id, extmark_line, actions)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local indent = M.get_indent(bufnr, extmark_line)
	local virt_lines = {
		{ { indent .. "Thinking", "Comment" } },
	}
	for _, a in ipairs(actions) do
		virt_lines[#virt_lines + 1] = { { indent .. "  " .. a, "NonText" } }
	end

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

---@param line string
---@return integer?, string?
function M.parse_line_tag(line)
	local ref, rest = line:match("^L(%d+):%s*(.*)$")
	if ref then
		return tonumber(ref), rest
	end
	ref, rest = line:match("^L(%d+)[%–%—%-]L%d+:%s*(.*)$")
	if ref then
		return tonumber(ref), rest
	end
	return nil, nil
end

---@param bufnr integer
---@param extmark_id integer
---@param start_0idx integer
---@param end_0idx integer
---@param answer string
function M.distribute_response(bufnr, extmark_id, start_0idx, end_0idx, answer)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)

	local lines = vim.split(answer, "\n")
	local max_width = math.max(20, vim.fn.winwidth(0) - 2)

	---@param list string[]
	---@param text string
	local function wrap_and_add(list, text)
		local trimmed = vim.trim(text)
		if trimmed == "" then
			return
		end
		while #trimmed > max_width do
			table.insert(list, trimmed:sub(1, max_width))
			trimmed = trimmed:sub(max_width + 1)
		end
		if #trimmed > 0 then
			table.insert(list, trimmed)
		end
	end

	local line_entries = {}
	local seq_lines = {}
	local has_refs = false
	local current_ref = nil

	for _, line in ipairs(lines) do
		local ref, rest = M.parse_line_tag(line)
		if ref then
			current_ref = ref - 1
			has_refs = true
			if not line_entries[current_ref] then
				line_entries[current_ref] = {}
			end
			wrap_and_add(line_entries[current_ref], rest)
		elseif has_refs then
			if current_ref then
				wrap_and_add(line_entries[current_ref], line)
			end
		else
			wrap_and_add(seq_lines, line)
		end
	end

	if has_refs then
		M._last_bufnr = bufnr
		M._last_refs = {}
		for linenr, entry in pairs(line_entries) do
			if linenr >= start_0idx and linenr <= end_0idx and #entry > 0 then
				M._last_refs[linenr] = table.concat(entry, " ")
			end
		end

		local chunks = {}
		for linenr, entry in pairs(line_entries) do
			if linenr >= start_0idx and linenr <= end_0idx and #entry > 0 then
				local chunk = {}
				for _, item in ipairs(entry) do
					table.insert(chunk, { { M.get_indent(bufnr, linenr) .. item, "Comment" } })
				end
				chunks[linenr] = chunk
			end
		end

		for linenr, chunk in pairs(chunks) do
			if #chunk > 0 then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, 0, {
					virt_lines = chunk,
				})
			end
		end
		return
	end

	if #seq_lines == 0 then
		return
	end

	local num_source_lines = end_0idx - start_0idx + 1
	local lines_per_source = math.max(1, math.ceil(#seq_lines / num_source_lines))

	M._last_bufnr = bufnr
	M._last_refs = {}

	local chunks = {}
	local idx = 1
	for linenr = start_0idx, end_0idx do
		local chunk = {}
		local items = {}
		for _ = 1, lines_per_source do
			if idx > #seq_lines then
				break
			end
			table.insert(chunk, { { M.get_indent(bufnr, linenr) .. seq_lines[idx], "Comment" } })
			table.insert(items, seq_lines[idx])
			idx = idx + 1
		end
		if #items > 0 then
			M._last_refs[linenr] = table.concat(items, " ")
		end
		chunks[linenr] = chunk
	end

	for linenr, chunk in pairs(chunks) do
		if #chunk > 0 then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, 0, {
				virt_lines = chunk,
			})
		end
	end
end

function M.insert_explanations()
	local bufnr = vim.api.nvim_get_current_buf()
	if M._last_bufnr ~= bufnr or not M._last_refs then
		vim.notify("Blip: no explanations to insert", vim.log.levels.WARN)
		return
	end

	local refs = M._last_refs
	M._last_bufnr = nil
	M._last_refs = nil

	local linenrs = {}
	for linenr_0idx, _ in pairs(refs) do
		table.insert(linenrs, linenr_0idx)
	end
	table.sort(linenrs, function(a, b)
		return a > b
	end)

	local count = 0
	for _, linenr_0idx in ipairs(linenrs) do
		local indent = M.get_indent(bufnr, linenr_0idx)
		local comment = indent .. comment_line(refs[linenr_0idx])
		vim.api.nvim_buf_set_lines(bufnr, linenr_0idx + 1, linenr_0idx + 1, false, { comment })
		count = count + 1
	end
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
	vim.notify(string.format("Blip: inserted %d explanation line(s)", count))
end

function M.clear()
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
end

return M
