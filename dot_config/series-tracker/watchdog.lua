-- Series Tracker watchdog for mpv
-- Tracks position continuously, writes state on shutdown
-- Env vars: ST_FLAG_FILE (watched flag), ST_POS_FILE (resume position)

local flag_file = os.getenv("ST_FLAG_FILE") or "/tmp/st-watched-flag"
local pos_file = os.getenv("ST_POS_FILE") or "/tmp/st-last-pos"

local last_percent = 0
local last_time = 0

mp.observe_property("percent-pos", "number", function(_, val)
    if val then last_percent = val end
end)

mp.observe_property("time-pos", "number", function(_, val)
    if val then last_time = val end
end)

mp.register_event("shutdown", function()
    if last_percent > 90 then
        local f = io.open(flag_file, "w")
        f:write("done")
        f:close()
    end

    if last_time > 0 then
        local f = io.open(pos_file, "w")
        f:write(tostring(math.floor(last_time)))
        f:close()
    end
end)
