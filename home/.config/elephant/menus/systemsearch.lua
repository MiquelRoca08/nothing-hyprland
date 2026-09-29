-- Main menu search (SUPER+SPACE) while typing: every entry of the system menu, including
-- the submenus', with its path («Actions › Screenshot › Region», translated by «menu --entries»). Read from ~/.local/bin/menu's
-- table («menu --entries»). walker adds the apps («menu» set in config.toml).
-- Picking a submenu opens it; picking an entry runs it directly.
Name = "systemsearch"
NamePretty = "Menu options"
Cache = false
HideFromProviderlist = true

local MENU = os.getenv("HOME") .. "/.local/bin/menu"

function GetEntries()
  local entries = {}
  local h = io.popen(MENU .. " --entries")
  if not h then return entries end
  for line in h:lines() do
    local path, icon, text, target = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if path then
      local label = text
      if path ~= "" then label = path:gsub("/", " › ") .. " › " .. text end
      local action
      if target:sub(1, 1) == ">" then
        action = MENU .. " --from-main '" .. target:sub(2) .. "'"
      else
        action = MENU .. " run " .. target
      end
      table.insert(entries, {
        Text = icon .. "  " .. label,
        Value = target,
        Actions = { activate = action },
      })
    end
  end
  h:close()
  return entries
end
