-- Wallpaper picker (≈ Omarchy 3.8.4's omarchy_background_selector.lua). Opened with
-- «walker-launch -m menus:fondos» (menu → Style → Wallpaper). Lists the images in
-- ~/Pictures/Wallpapers with a preview and sets them as wallpaper through the shell's IPC; the first
-- entry goes back to the dot grid.
Name = "fondos"
NamePretty = "Wallpapers"
Cache = false
HideFromProviderlist = true
SearchName = true

local function escapar(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- «cyan_2.0_5-030626.png» → «Cyan 2.0 5 030626»
local function nombre(archivo)
  local n = archivo:gsub("%.[^%.]+$", ""):gsub("[-_]", " ")
  return (n:gsub("^%l", string.upper))
end

-- A text in the interface language (the shell's dictionary, through i18n.sh)
local function t(s)
  local h = io.popen("bash -c 'source ~/.config/quickshell/i18n/i18n.sh 2>/dev/null && t \"$1\" || printf %s \"$1\"' _ " .. escapar(s))
  if not h then return s end
  local r = h:read("*a")
  h:close()
  return (r ~= "" and r) or s
end

function GetEntries()
  local entradas = {
    {
      Text = t("Dots (no image)"),
      Value = "puntos",
      Actions = { activate = "qs ipc call wallpaper dots" },
    },
  }
  local dir = os.getenv("HOME") .. "/Pictures/Wallpapers"
  local h = io.popen("find -L " .. escapar(dir)
    .. " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) 2>/dev/null | sort")
  if h then
    for ruta in h:lines() do
      table.insert(entradas, {
        Text = nombre(ruta:match("([^/]+)$")),
        Value = ruta,
        Actions = { activate = "qs ipc call wallpaper set " .. escapar(ruta) },
        Preview = ruta,
        PreviewType = "file",
      })
    end
    h:close()
  end
  return entradas
end
