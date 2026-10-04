require('packer').startup(function(use) -- Package manager
	use 'wbthomason/packer.nvim'

	use 'neovim/nvim-lspconfig' -- Configurations for Nvim LSP
	--	use "folke/neodev.nvim"
	use {
		"hrsh7th/nvim-cmp",
		requires = {
			"hrsh7th/cmp-buffer", "hrsh7th/cmp-nvim-lsp",
			'quangnguyen30192/cmp-nvim-ultisnips', 'hrsh7th/cmp-nvim-lua',
			'octaltree/cmp-look', 'hrsh7th/cmp-path', 'hrsh7th/cmp-calc',
			'f3fora/cmp-spell', 'hrsh7th/cmp-emoji', 'hrsh7th/vim-vsnip'
		}
	}
	use { 'hrsh7th/vim-vsnip' }
	use {
		"j-hui/fidget.nvim",
		config = function()
			require("fidget").setup()
		end
	}
	--	use "EdenEast/nightfox.nvim"
	use "folke/neodev.nvim"
	use 'williamboman/mason.nvim'
	use 'simrat39/rust-tools.nvim'
	--	use { 'rafcamlet/nvim-luapad', requires = "antoinemadec/FixCursorHold.nvim" }
	use {
		'nvim-telescope/telescope.nvim', tag = '0.1.0',
		-- or                            , branch = '0.1.x',
		requires = { { 'nvim-lua/plenary.nvim' } }
	} -- Theme inspired by Atom
	--use 'joshdick/onedark.vim'
	use { "navarasu/onedark.nvim" }

--	use { "akinsho/toggleterm.nvim", tag = '*', config =
--	function()
--		require("toggleterm").setup()
--	end }
--	use { 'hkupty/iron.nvim', tag = '0.3' }

end)



