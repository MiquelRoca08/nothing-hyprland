-- Environment variables — https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_SIZE", "32")

-- Cursor: Windows 11 Fluent v2 Dark if installed (Win11-Fluent-Dark in ~/.local/share/icons;
-- not redistributable, so it is not in the repo: see docs/SYSTEM.md); otherwise XCursor-Pro-Dark
-- (free, downloaded by install.sh), from which Win11-Fluent-Dark inherits what it lacks
local fluent = io.open(os.getenv("HOME") .. "/.local/share/icons/Win11-Fluent-Dark/index.theme")
local cursor = fluent and "Win11-Fluent-Dark" or "XCursor-Pro-Dark"
if fluent then fluent:close() end
hl.env("XCURSOR_THEME", cursor)
hl.env("HYPRCURSOR_THEME", cursor)

-- ~/.local/bin in PATH (walker-launch, walker-restart…), without repeating it on config reload.
-- autostart.lua also passes it to the user services (walker runs things from there).
local bin = os.getenv("HOME") .. "/.local/bin"
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if not (":" .. path .. ":"):find(":" .. bin .. ":", 1, true) then
    hl.env("PATH", bin .. ":" .. path)
end
