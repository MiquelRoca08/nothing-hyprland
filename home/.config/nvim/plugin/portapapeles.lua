-- System clipboard with wl-clipboard (Wayland): y, d, c and p use Hyprland's clipboard,
-- without a "+ prefix. Only this file is linked (not all of ~/.config/nvim): nvim always loads
-- plugin/*.lua, whether there is an init.lua, LazyVim or nothing.
-- Needs wl-clipboard (wl-copy and wl-paste). Check: :checkhealth provider
vim.opt.clipboard = "unnamedplus"

-- Explicit so it does not use xclip/xsel through XWayland. Without Wayland (e.g. over SSH) nvim picks
-- by itself (OSC 52 in nvim ≥ 0.10)
if vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1 then
  vim.g.clipboard = {
    name = "wl-clipboard",
    copy = {
      ["+"] = { "wl-copy", "--type", "text/plain" },
      ["*"] = { "wl-copy", "--primary", "--type", "text/plain" },
    },
    paste = {
      ["+"] = { "wl-paste", "--no-newline" },
      ["*"] = { "wl-paste", "--no-newline", "--primary" },
    },
    cache_enabled = true,
  }
end

-- Ctrl+Shift+C: nvim captures the mouse, so dragging selects in nvim (visual mode) and not in
-- Alacritty; Alacritty's Ctrl+Shift+C copies its own selection, which is empty, and the key never
-- reaches nvim. So a mouse selection is copied on release (and stays
-- selected): afterwards Ctrl+Shift+C does nothing and Ctrl+Shift+V / Ctrl+V paste what was copied.
-- With the keyboard (v…), copy with y. Shift+drag selects in Alacritty, as outside nvim.
vim.keymap.set("x", "<LeftRelease>", '<LeftRelease>"+ygv', { silent = true, desc = "Copiar la selección del ratón" })
-- In case the terminal does pass the key to nvim (other terminals, or Alacritty without that bind)
vim.keymap.set("x", "<C-S-c>", '"+y', { silent = true, desc = "Copiar al portapapeles" })
