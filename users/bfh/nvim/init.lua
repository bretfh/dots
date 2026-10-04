require('plugin')
--require("neodev").setup({})
require('completions')
require('lsp')
require('ts')

vim.opt.termguicolors = true
vim.g.mapleader = " "
vim.g.maplocalleader=" "
vim.o.completeopt = "menu,menuone,noinsert,noselect"
vim.opt.guifont = { "fira code", ":h16" }

local lspconfig = require 'lspconfig'

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
vim.keymap.set('n', '<leader>ft', function() vim.cmd('terminal')end, {}) 


require("mason").setup({
	ui = {
		icons = {
			package_installed = "✓",
			package_pending = "➜",
			package_uninstalled = "✗"
		}
	}
})


function _G.set_terminal_keymaps()
	local termopts = { buffer = 0 }
	vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], termopts)
	vim.keymap.set('t', 'jk', [[<C-\><C-n>]], termopts)
	vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], termopts)
	vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], termopts)
	vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], termopts)
	vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], termopts)
end

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

require('onedark').setup {
	-- Main options --
	style = 'darker', -- Default theme style. Choose between 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer' and 'light'
	transparent = true, -- Show/hide background
	term_colors = true, -- Change terminal color as per the selected theme style
	ending_tildes = false, -- Show the end-of-buffer tildes. By default they are hidden
	cmp_itemkind_reverse = false, -- reverse item kind highlights in cmp menu

	-- toggle theme style ---
	toggle_style_key = "<leader>ts", -- keybind to toggle theme style. Leave it nil to disable it, or set it to a string, for example "<leader>ts"
	toggle_style_list = { 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer', 'light' }, -- List of styles to toggle between

	-- Change code style ---
	-- Options are italic, bold, underline, none
	-- You can configure multiple style with comma seperated, For e.g., keywords = 'italic,bold'
	code_style = {
		comments = 'italic',
		keywords = 'none',
		functions = 'none',
		strings = 'none',
		variables = 'none'
	},

	-- Lualine options --
	lualine = {
		transparent = false, -- lualine center bar transparency
	},

	-- Custom Highlights --
	colors = {}, -- Override default colors
	highlights = {}, -- Override highlight groups

	-- Plugins Config --
	diagnostics = {
		darker = true, -- darker colors for diagnostic
		undercurl = true, -- use undercurl instead of underline for diagnostics
		background = true, -- use background color for virtual text
	},
}

vim.cmd('colorscheme onedark')
vim.opt.tabline = "1"
vim.opt.showtabline = 2
vim.opt.showcmd = false
vim.opt.laststatus = 3
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.cmdheight = 0
