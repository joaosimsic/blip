---@meta

---@alias SupportedModes "n" | "v"

---@alias BlipDelimiters [number, number]

---@class BlipOpts
---@field visual? boolean

---@class BlipState
---@field bufnr integer
---@field extmark_id integer
---@field extmark_line integer
---@field start_0idx integer
---@field api_key string
---@field project_root string
---@field actions string[]
---@field stream_line_count integer
---@field stream_placed_lines table<integer,boolean>
---@field stream_active_linenr integer?
---@field stream_active_extmark_id integer?

---@class BlipToolCall
---@field id string
---@field type string
---@field ["function"] BlipToolCallFunc

---@class BlipToolCallFunc
---@field name string
---@field arguments string

---@class BlipMessage
---@field role string
---@field content string
---@field tool_calls? BlipToolCall[]
---@field tool_call_id? string

---@class BlipToolDefinition
---@field type string
---@field ["function"] BlipToolDefinitionFunc

---@class BlipToolDefinitionFunc
---@field name string
---@field description string
---@field parameters BlipToolParameters

---@class BlipToolParameters
---@field type string
---@field properties table<string, BlipToolProperty>
---@field required string[]

---@class BlipToolProperty
---@field type string
---@field description string

---@class Blip
---@field ask fun(nil): nil
---@field dismiss fun(nil): nil
---@field comment fun(nil): nil
