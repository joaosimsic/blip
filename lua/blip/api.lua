---@class BlipApiConfig
---@field base_url string
---@field model string
---@field max_tokens integer

---@type BlipApiConfig
local config = {
	base_url = "https://opencode.ai/zen/go/v1",
	model = "deepseek-v4-flash",
	max_tokens = 8192,
}

local M = {}

---@param api_key string
---@return table<string,string>
local function build_headers(api_key)
	return {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. api_key,
	}
end

---@param messages BlipMessage[]
---@param tools table[]?
---@param api_key string
---@param on_success fun(message: BlipMessage)
---@param on_error fun(msg: string)
function M.chat(messages, tools, api_key, on_success, on_error)
	local curl = require("plenary.curl")

	local body = {
		model = config.model,
		messages = messages,
		max_tokens = config.max_tokens,
		stream = false,
	}
	if tools then
		body.tools = tools
		body.tool_choice = "auto"
	end

	local json_body = vim.fn.json_encode(body)

	vim.notify(string.format("chat: %d messages, tools=%s", #messages, tostring(tools ~= nil)), vim.log.levels.INFO)

	curl.request({
		url = config.base_url .. "/chat/completions",
		method = "POST",
		headers = build_headers(api_key),
		body = json_body,
		timeout = 30000,
		callback = vim.schedule_wrap(function(response)
			if response.exit ~= 0 then
				on_error("curl error (exit " .. response.exit .. ")")
				return
			end

			if response.status and response.status >= 400 then
				local msg = "HTTP " .. response.status
				local ok, res = pcall(vim.fn.json_decode, tostring(response.body))
				if ok and res and res.error then
					msg = msg .. ": " .. (type(res.error) == "table" and (res.error.message or vim.inspect(res.error)) or tostring(res.error))
				end
				on_error(msg)
				return
			end

			local ok, data = pcall(vim.fn.json_decode, response.body)
			if not ok or not data.choices or not data.choices[1] then
				on_error("Invalid API response")
				return
			end

			on_success(data.choices[1].message)
		end),
	})
end

---@param messages BlipMessage[]
---@param api_key string
---@param on_delta fun(chunk: string, accumulated: string)
---@param on_complete fun(full_content: string)
---@param on_error fun(msg: string)
function M.chat_stream(messages, api_key, on_delta, on_complete, on_error)
	local curl = require("plenary.curl")

	local json_body = vim.fn.json_encode({
		model = config.model,
		messages = messages,
		max_tokens = config.max_tokens,
		stream = true,
	})

	local sse_buffer = ""
	local accumulated = ""
	local completed = false

	local function process_sse()
		while true do
			local dbl = sse_buffer:find("\n\n")
			if not dbl then break end

			local event = sse_buffer:sub(1, dbl - 1)
			sse_buffer = sse_buffer:sub(dbl + 2)

			for line in event:gmatch("[^\r\n]+") do
				local payload = line:match("^data: (.*)$")
				if payload then
					if payload == "[DONE]" then return true end
					local ok, json = pcall(vim.fn.json_decode, payload)
					if ok and json.choices and json.choices[1] then
						local delta = json.choices[1].delta or {}
						local chunk = delta.content
						if type(chunk) == "string" then
							accumulated = accumulated .. chunk
							on_delta(chunk, accumulated)
						end
					end
				end
			end
		end
		return false
	end

	local stream_handler = vim.schedule_wrap(function(err, data)
		if completed then return end
		if err then
			completed = true
			on_error("Stream error: " .. tostring(err))
			return
		end
		if data == nil then return end

		sse_buffer = sse_buffer .. data .. "\n"
		if process_sse() then
			completed = true
			on_complete(accumulated)
		end
	end)

	local callback = vim.schedule_wrap(function(response)
		if completed then return end
		completed = true

		if response.exit ~= 0 then
			on_error("curl error (exit " .. response.exit .. ")")
			return
		end
		if response.status and response.status >= 400 then
			on_error("HTTP " .. response.status)
			return
		end
		if vim.trim(accumulated or "") ~= "" then
			on_complete(accumulated)
		else
			on_error("Empty response from API")
		end
	end)

	curl.request({
		url = config.base_url .. "/chat/completions",
		method = "POST",
		headers = build_headers(api_key),
		body = json_body,
		timeout = 30000,
		stream = stream_handler,
		callback = callback,
	})
end

return M
