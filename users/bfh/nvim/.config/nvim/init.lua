require('plugin')
require("neodev").setup({})
require('completions')
require('lsp')
require('ts')

local lspconfig = require 'lspconfig'
local builtin = require('telescope.builtin')

vim.opt.termguicolors = true
vim.g.mapleader = " "
vim.g.maplocalleader=" "
vim.g.nvlime_config = {
	leader = vim.g.maplocalleader,
	cmp = {enabled = true},
	implementation = "ros",
	address = {
		host = "127.0.0.1",
		port = 7002
	}
}
vim.o.completeopt = "menu,menuone,noinsert,noselect"
vim.opt.guifont = { "fira code", ":h16" }
--vim.opt.tabline = "1"
vim.opt.showtabline = 2
vim.opt.showcmd = false
vim.opt.laststatus = 3
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.cmdheight = 1

vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
--vim.keymap.set('n', vim.g.mapleader .. 'r', ':call nvlime#server#BuildServerCommand()<CR>', { noremap = true, silent = true})
--vim.keymap.set('n', vim.g.mapleader .. 'r', ':call nvlime#server#start()<CR>', {noremap = true, silent = true})

require("mason").setup({
	ui = {
		icons = {
			package_installed = "✓",
			package_pending = "➜",
			package_uninstalled = "✗"
		}
	}
})

--local rt = require("rust-tools")
--
--rt.setup({
--	server = {
--		on_attach = function(_, bufnr)
--			-- Hover actions
--			vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
--			-- Code action groups
--			vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
--		end,
--	},
--})

--function _G.set_terminal_keymaps()
--	local termopts = { buffer = 0 }
--	vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], termopts)
--	vim.keymap.set('t', 'jk', [[<C-\><C-n>]], termopts)
--	vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], termopts)
--	vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], termopts)
--	vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], termopts)
--	vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], termopts)
--end
--vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

require("tokyonight").setup({
  style = "storm", -- `storm`, `moon`
  light_style = "day",
  transparent = true,
  terminal_colors = true,
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
    functions = {},
    variables = {},
    -- Background styles. Can be "dark", "transparent" or "normal"
    sidebars = "dark",
    floats = "dark",
  },
  sidebars = { "qf", "help" },
  day_brightness = 0.3,
  hide_inactive_statusline = false,
  dim_inactive = true,
  lualine_bold = false,
  on_colors = function(colors) end,
  on_highlights = function(highlights, colors) end,
})
vim.cmd('colorscheme tokyonight')
