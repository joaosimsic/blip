local M = {}

---@type BlipToolDefinition[]
M.definitions = {
	{
		type = "function",
		["function"] = {
			name = "search_code",
			description = "Search the codebase using ripgrep. Returns matching file:line:content results with paths relative to project root.",
			parameters = {
				type = "object",
				properties = {
					query = { type = "string", description = "Search query (regex supported)" },
					max_results = { type = "number", description = "Maximum number of results (default 15)" },
					include = { type = "string", description = "File glob filter (e.g. '*.rs', '*.{ts,tsx}')" },
				},
				required = { "query" },
			},
		},
	},
	{
		type = "function",
		["function"] = {
			name = "read_file_lines",
			description = "Read specific lines from a file relative to project root. Defaults to max 5 lines (lines start_line through start_line+4).",
			parameters = {
				type = "object",
				properties = {
					path = { type = "string", description = "Relative path from project root" },
					start_line = { type = "number", description = "First line to read (1-indexed, default 1)" },
					end_line = {
						type = "number",
						description = "Last line to read (inclusive, defaults to start_line + 4)",
					},
				},
				required = { "path" },
			},
		},
	},
}

---@param bufnr integer
---@return string
function M.find_project_root(bufnr)
	local buf_path = vim.api.nvim_buf_get_name(bufnr)
	if buf_path == "" then
		return vim.fn.getcwd()
	end
	local dir = vim.fn.fnamemodify(buf_path, ":h")
	local root = vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel 2>/dev/null")
	if vim.v.shell_error == 0 then
		return vim.trim(root)
	end
	return vim.fn.getcwd()
end

---@param query string
---@param max_results integer
---@param include string?
---@param project_root string
---@return string
local function search_code(query, max_results, include, project_root)
	local saved = vim.uv.cwd()
	vim.uv.chdir(project_root)
	local cmd = { "rg", "--no-heading", "--line-number", "--color=never", "--smart-case" }
	if include then
		table.insert(cmd, "--glob")
		table.insert(cmd, include)
	end
	table.insert(cmd, query)
	table.insert(cmd, ".")

	local output = vim.fn.system(cmd)
	vim.uv.chdir(saved)
	if vim.v.shell_error ~= 0 then
		return "No results found."
	end

	local lines = vim.split(output, "\n")
	local results = {}
	for i = 1, math.min(#lines, max_results) do
		if lines[i] ~= "" then
			table.insert(results, lines[i])
		end
	end
	return table.concat(results, "\n")
end

---@param path string
---@param start_line integer?
---@param end_line integer?
---@param project_root string
---@return string
local function read_file_lines(path, start_line, end_line, project_root)
	local full_path = path
	if path:sub(1, 1) ~= "/" then
		full_path = project_root .. "/" .. path
	end

	local ok, lines = pcall(vim.fn.readfile, full_path)
	if not ok or type(lines) ~= "table" then
		return "Error: could not read file '" .. path .. "'"
	end

	local s = start_line or 1
	local e = end_line or math.min(s + 4, #lines)
	s = math.max(1, s)
	e = math.min(e, #lines)

	local result = {}
	for i = s, e do
		table.insert(result, string.format("%d: %s", i, lines[i]))
	end
	return table.concat(result, "\n")
end

---@param name string
---@param args table
---@param project_root string
---@return string
function M.execute(name, args, project_root)
	if name == "search_code" then
		return search_code(args.query, args.max_results or 15, args.include, project_root)
	elseif name == "read_file_lines" then
		return read_file_lines(args.path, args.start_line, args.end_line, project_root)
	end
	return "Error: unknown tool '" .. name .. "'"
end

return M
