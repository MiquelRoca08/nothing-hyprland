-- Wallpaper picker (≈ Omarchy 3.8.4's omarchy_background_selector.lua). Opened with
-- «walker-launch -m menus:wallpapers» (menu → Style → Wallpaper). Lists the images in
-- ~/Pictures/Wallpapers with a preview and sets them as wallpaper through the shell's IPC; the first
-- entry goes back to the dot grid.
Name = "wallpapers"
NamePretty = "Wallpapers"
-- Cached: listed again only when the folder or the language (i18n/es.js, /etc/locale.conf)
-- changes, not on every keystroke (see system.lua). Folders, not files: renames drop file watches
Cache = true
RefreshOnChange = {
  os.getenv("HOME") .. "/Pictures/Wallpapers",
  os.getenv("HOME") .. "/.config/quickshell/i18n",
  "/etc",
}
HideFromProviderlist = true
SearchName = true

local function quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- «cyan_2.0_5-030626.png» → «Cyan 2.0 5 030626»
local function label(file)
  local n = file:gsub("%.[^%.]+$", ""):gsub("[-_]", " ")
  return (n:gsub("^%l", string.upper))
end

-- A text in the interface language (the shell's dictionary, through i18n.sh)
local function t(s)
  local h = io.popen("bash -c 'source ~/.config/quickshell/i18n/i18n.sh 2>/dev/null && t \"$1\" || printf %s \"$1\"' _ " .. quote(s))
  if not h then return s end
  local r = h:read("*a")
  h:close()
  return (r ~= "" and r) or s
end

function GetEntries()
  local entries = {
    {
      Text = t("Dots (no image)"),
      Value = "dots",
      Actions = { activate = "qs ipc call wallpaper dots" },
    },
  }
  local dir = os.getenv("HOME") .. "/Pictures/Wallpapers"
  local h = io.popen("find -L " .. quote(dir)
    .. " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) 2>/dev/null | sort")
  if h then
    for path in h:lines() do
      table.insert(entries, {
        Text = label(path:match("([^/]+)$")),
        Value = path,
        Actions = { activate = "qs ipc call wallpaper set " .. quote(path) },
        Preview = path,
        PreviewType = "file",
      })
    end
    h:close()
  end
  return entries
end
