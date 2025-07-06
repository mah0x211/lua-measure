--
-- Common helper module for creating mock samples in tests
--
local samples = require('measure.samples')

-- Default values for mock samples
local DEFAULT_CONFIDENCE_LEVEL = 95 -- 95% confidence level
local DEFAULT_RCIW = 5.0 -- 5% relative confidence interval width
local DEFAULT_BASE_KB = 1 -- Base memory in KB
local DEFAULT_GC_STEP = 0 -- GC step value

--- Helper function to create mock samples with known time values
--- @param time_values table Array of time values in nanoseconds
--- @param confidence_level number? Optional confidence level (default: 95)
--- @param rciw number? Optional relative confidence interval width (default: 5.0)
--- @param opts table? Optional additional options for sample data
--- @return measure.samples Mock samples instance
local function create_mock_samples(time_values, confidence_level, rciw, opts)
    opts = opts or {}
    confidence_level = confidence_level or DEFAULT_CONFIDENCE_LEVEL
    rciw = rciw or DEFAULT_RCIW

    local count = #time_values
    local data = {
        time_ns = {},
        before_kb = {},
        after_kb = {},
        allocated_kb = {},
        capacity = opts.capacity or count,
        count = count,
        gc_step = opts.gc_step or DEFAULT_GC_STEP,
        base_kb = opts.base_kb or DEFAULT_BASE_KB,
        cl = confidence_level,
        rciw = rciw,
    }

    -- Populate time values
    for i, time_ns in ipairs(time_values) do
        data.time_ns[i] = time_ns
        data.before_kb[i] = opts.before_kb and opts.before_kb[i] or 0
        data.after_kb[i] = opts.after_kb and opts.after_kb[i] or 0
        data.allocated_kb[i] = opts.allocated_kb and opts.allocated_kb[i] or 0
    end

    local s, err = samples(data)
    if not s then
        error("Failed to create mock samples: " .. (err or "unknown error"))
    end
    return s
end

--- Helper function to create mock samples with memory data (alias for compatibility)
--- @param time_values table Array of time values in nanoseconds
--- @param memory_opts table Memory data options with before_kb, after_kb, allocated_kb arrays
--- @param confidence_level number? Optional confidence level (default: 95)
--- @param rciw number? Optional relative confidence interval width (default: 5.0)
--- @return measure.samples Mock samples instance
local function create_mock_samples_with_memory(time_values, memory_opts,
                                               confidence_level, rciw)
    return create_mock_samples(time_values, confidence_level, rciw, memory_opts)
end

return {
    create_mock_samples = create_mock_samples,
    create_mock_samples_with_memory = create_mock_samples_with_memory,
    -- Export constants for use in tests
    DEFAULT_CONFIDENCE_LEVEL = DEFAULT_CONFIDENCE_LEVEL,
    DEFAULT_RCIW = DEFAULT_RCIW,
    DEFAULT_BASE_KB = DEFAULT_BASE_KB,
    DEFAULT_GC_STEP = DEFAULT_GC_STEP,
}
