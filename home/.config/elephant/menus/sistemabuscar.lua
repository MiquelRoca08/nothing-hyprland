-- Main menu search (SUPER+SPACE) while typing: every entry of the system menu, including
-- the submenus', with its path («Actions › Screenshot › Region», translated by «menu --entradas»). Read from ~/.local/bin/menu's
-- table («menu --entradas»). walker adds the apps («menu» set in config.toml).
-- Picking a submenu opens it; picking an entry runs it directly.
Name = "sistemabuscar"
NamePretty = "Menu options"
Cache = false
HideFromProviderlist = true

local MENU = os.getenv("HOME") .. "/.local/bin/menu"

function GetEntries()
  local entradas = {}
  local h = io.popen(MENU .. " --entradas")
  if not h then return entradas end
  for linea in h:lines() do
    local ruta, icono, texto, destino = linea:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if ruta then
      local nombre = texto
      if ruta ~= "" then nombre = ruta:gsub("/", " › ") .. " › " .. texto end
      local accion
      if destino:sub(1, 1) == ">" then
        accion = MENU .. " --desde-principal '" .. destino:sub(2) .. "'"
      else
        accion = MENU .. " hacer " .. destino
      end
      table.insert(entradas, {
        Text = icono .. "  " .. nombre,
        Value = destino,
        Actions = { activate = accion },
      })
    end
  end
  h:close()
  return entradas
end
