-- Main menu (SUPER+SPACE) without typing: the system menu's sections, in their
-- order. Read from ~/.local/bin/menu's table («menu --entries»). Picking a section opens
-- its submenu (menu --from-main); standalone entries (Apps, Settings) run directly.
-- The texts come already translated from «menu --entries».
-- Searching every entry lives in systemsearch.lua.
Name = "system"
NamePretty = "System menu"
-- Cached: elephant calls GetEntries again only when something that changes the entries does: the
-- script (its real folder: ~/.local/bin/menu is a link into the repo), settings.json (hidden
-- entries, order, custom ones), the language (es.js, /etc/locale.conf) and the installed packages
-- (entries that need a program). Without the cache it ran «menu --entries» (~135 ms) on every
-- keystroke. Folders, not files: a file watch is lost when the file is replaced by a rename
-- (atomic saves: Quickshell, localectl, editors, git)
Cache = true
local HOME = os.getenv("HOME")
local function real_dir(path)
  local h = io.popen("dirname \"$(readlink -f '" .. path .. "')\"")
  local dir = h and h:read("*l")
  if h then h:close() end
  return dir ~= "" and dir or HOME .. "/.local/bin"
end
RefreshOnChange = {
  real_dir(HOME .. "/.local/bin/menu"),
  HOME .. "/.config/quickshell",
  HOME .. "/.config/quickshell/i18n",
  "/etc",
  "/var/lib/pacman/local",
}
HideFromProviderlist = true
FixedOrder = true

local MENU = HOME .. "/.local/bin/menu"

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
        -- The glyph as the icon, not inside the text: walker draws it in its own 32 px box
        -- (.item-image-text), like the apps' icons, so every row lines up
        Icon = icon,
        Text = text,
        Value = target,
        Actions = { activate = action },
      })
    end
  end
  h:close()
  return entries
end
