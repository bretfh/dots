(local packer (require :packer))

(packer.startup (fn [use]
                  (use :wbthomason/packer.nvim)
                  (use :nvim-treesitter/nvim-treesitter)
                  (use :atweiden/vim-fennel)
                  (use :Olical/conjure)
                  (use :PaterJason/cmp-conjure)
                  (use :neovim/nvim-lspconfig)
                  (use {1 :hrsh7th/nvim-cmp
                       :requires [:hrsh7th/cmp-buffer
                                   :hrsh7th/cmp-nvim-lsp
                                   :quangnguyen30192/cmp-nvim-ultisnips
                                   :hrsh7th/cmp-nvim-lua
                                   :octaltree/cmp-look
                                   :hrsh7th/cmp-path
                                   :hrsh7th/cmp-calc
                                   :f3fora/cmp-spell
                                   :hrsh7th/cmp-emoji
                                   :hrsh7th/vim-vsnip]})
                  (use [:hrsh7th/vim-vsnip])
                  (use {1 :j-hui/fidget.nvim
                       :config (fn []
                                 ((. (require :fidget) :setup)))})
                  (use :folke/neodev.nvim)
                  (use :williamboman/mason.nvim)
                  (use :simrat39/rust-tools.nvim)
                  (use {1 :nvim-telescope/telescope.nvim
                       :tag :0.1.0
                       :requires [[:nvim-lua/plenary.nvim]]})
                  (use [:navarasu/onedark.nvim])))	


