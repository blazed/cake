local g = vim.g
local opt = vim.opt

g.mapleader = ","

opt.termguicolors = true

opt.number = true
opt.relativenumber = true

opt.shell = "nu"

opt.cursorline = true
opt.cursorcolumn = false
opt.colorcolumn = "80,120"
opt.signcolumn = "yes:1"
opt.showmode = false

opt.clipboard = "unnamedplus"
opt.completeopt = "menu,menuone,noselect"

opt.expandtab = true
opt.shiftwidth = 2
opt.softtabstop = 2
opt.smartindent = true
opt.tabstop = 2

opt.list = true
opt.listchars = {
  tab = "▸ ",
  trail = "·",
  precedes = "←",
  extends = "→",
  nbsp = "+",
  eol = "↲",
}

opt.fillchars = { eob = " ", diff = "" }
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"

opt.timeout = true
opt.timeoutlen = 500

opt.splitright = true
opt.splitbelow = true
opt.equalalways = true

opt.showtabline = 1

opt.wrap = false

-- opt.whichwrap:append {
--     ["<"] = true,
--     [">"] = true,
--     ["["] = true,
--     ["]"] = true,
--     h = true,
--     l = true,
-- }

opt.autoread = true
opt.autowrite = true
opt.autowriteall = true

opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,terminal,localoptions"

g.loadednetrw = 1
g.loaded_netrwPlugin = 1
