-- Main menu (SUPER+SPACE) without typing: the system menu's sections, in their
-- order. Read from ~/.local/bin/menu's table («menu --entries»). Picking a section opens
-- its submenu (menu --from-main); standalone entries (Apps, Settings) run directly.
-- The texts come already translated from «menu --entries».
-- Searching every entry lives in systemsearch.lua.
Name = "system"
NamePretty = "System menu"
Cache = false
HideFromProviderlist = true
FixedOrder = true

local MENU = os.getenv("HOME") .. "/.local/bin/menu"

function GetEntries()
  local entries = {}
  local h = io.popen(MENU .. " --entries")
  if not h then return entries end
  for line in h:lines() do
    local path, icon, text, target = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if path == "" then
      local action
      if target:sub(1, 1) == ">" then
        action = MENU .. " --from-main '" .. target:sub(2) .. "'"
      else
        action = MENU .. " run " .. target
      end
      table.insert(entries, {
        Text = icon .. "  " .. text,
        Value = target,
        Actions = { activate = action },
      })
    end
  end
  h:close()
  return entries
end
