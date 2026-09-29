-- Main menu (SUPER+SPACE) without typing: the system menu's sections, in their
-- order. Read from ~/.local/bin/menu's table («menu --entradas»). Picking a section opens
-- its submenu (menu --desde-principal); standalone entries (Apps, Settings) run directly.
-- The texts come already translated from «menu --entradas».
-- Searching every entry lives in sistemabuscar.lua.
Name = "sistema"
NamePretty = "System menu"
Cache = false
HideFromProviderlist = true
FixedOrder = true

local MENU = os.getenv("HOME") .. "/.local/bin/menu"

function GetEntries()
  local entradas = {}
  local h = io.popen(MENU .. " --entradas")
  if not h then return entradas end
  for linea in h:lines() do
    local ruta, icono, texto, destino = linea:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if ruta == "" then
      local accion
      if destino:sub(1, 1) == ">" then
        accion = MENU .. " --desde-principal '" .. destino:sub(2) .. "'"
      else
        accion = MENU .. " hacer " .. destino
      end
      table.insert(entradas, {
        Text = icono .. "  " .. texto,
        Value = destino,
        Actions = { activate = accion },
      })
    end
  end
  h:close()
  return entradas
end
