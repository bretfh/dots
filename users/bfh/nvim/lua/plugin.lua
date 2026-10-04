local fn = vim.fn
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({
    'git',
    'clone',
    '--depth',
    '1',
    'https://github.com/wbthomason/packer.nvim',
    install_path
  })
  vim.o.runtimepath = vim.fn.stdpath('data') .. '/site/pack/*/start/*,' .. vim.o.runtimepath
end

vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugin.lua source <afile> | PackerSync
  augroup end
]]

local status_ok, packer = pcall(require, 'packer')
if not status_ok then
  return
end

return packer.startup(function(use)
  use 'wbthomason/packer.nvim' 
  use 'kyazdani42/nvim-tree.lua'
  use 'lukas-reineke/indent-blankline.nvim'
  use {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup{}
    end
  }
  use 'kyazdani42/nvim-web-devicons'
  use 'preservim/tagbar'
  use {
    'nvim-treesitter/nvim-treesitter',
    run = function() require('nvim-treesitter.install').update({ with_sync = true }) end,
  }
  use 'navarasu/onedark.nvim'
  use 'folke/tokyonight.nvim'
  use 'tanvirtin/monokai.nvim'
  use { 'rose-pine/neovim', as = 'rose-pine' }
  use 'neovim/nvim-lspconfig'
  use {
    'hrsh7th/nvim-cmp',
    requires = {
      'L3MON4D3/LuaSnip',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-buffer',
      'saadparwaiz1/cmp_luasnip',
    },
  }
  use {
    'feline-nvim/feline.nvim',
    requires = { 'kyazdani42/nvim-web-devicons' },
    config = function()
	    require('feline').setup()
	    require('feline').winbar.setup()
    end
  }
  use {
    'lewis6991/gitsigns.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('gitsigns').setup{}
    end
  }
  use {
    'goolord/alpha-nvim',
    requires = { 'kyazdani42/nvim-web-devicons' },
    config = function ()
	    require'alpha'.setup(require'alpha.themes.startify'.config)
    end
  }
  use { 'nvim-telescope/telescope.nvim' }
  use { "williamboman/mason.nvim" }
  use "folke/neodev.nvim"
  use {"akinsho/toggleterm.nvim", tag = '*', config = function()
	  require("toggleterm").setup{
		  open_mapping = [[<c-\>]],
		  shade_terminals = true,
		  shade_filetypes = {},
		  hide_numbers = true,
		  shading_factor = 2,
		  shell = vim.o.shell,
		  direction = 'float',
		  float_opts = {
			  border = 'curved',
			  winblend = 5,
			  hightlights = {
				  border = "Normal",
				  background = "Normal",
			  },
		  },
	  }
  end}
 use 'pearofducks/ansible-vim'

  if packer_bootstrap then
	  require('packer').sync()
  end
end)
