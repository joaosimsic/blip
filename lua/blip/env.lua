---@class Env
---@field get_mode fun(nil): SupportedModes | nil
local M = {}

---@return SupportedModes | nil
function M.get_mode()
	local mode_code = vim.api.nvim_get_mode().mode

	local visual_modes = {
		["v"] = true,
		["V"] = true,
		["\22"] = true,
	}

	if mode_code == "n" then
		return "n"
	end

	if visual_modes[mode_code] then
		return "v"
	end

	return nil
end

return M
