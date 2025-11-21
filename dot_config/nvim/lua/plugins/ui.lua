return {
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        init = function()
            -- Don't show statusline until lualine has loaded
            vim.g.lualine_laststatus = vim.o.laststatus
            if vim.fn.argc(-1) > 0 then
                vim.o.statusline = " "
            else
                vim.opt.laststatus = 3
            end
        end,

        opts = {
            options = {
                section_separators = "",
                component_separators = "│",
                disabled_filetypes = { "neo-tree", "toggleterm" }
            }
        },
        config = function(_, opts)
            require("lualine").setup(opts)
            vim.cmd([[ :set noshowmode ]])
        end
    },
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPost", "BufNewFile"},
        main = "ibl",
        opts = {
            indent = {
                char = "│",
                tab_char = "│"
            },
            scope = { show_start = false, show_end = false },
            exclude = {
                filetypes = {
                    "neo-tree",
                    "Trouble",
                    "trouble",
                    "lazy",
                    "mason",
                    "toggleterm"
                }
            }
        }
    },
    {
        "https://github.com/RRethy/vim-illuminate",
        event = { "BufReadPost", "BufNewFile"},

        config = function()
            require("illuminate").configure({
                modes_denylist = { "v", "V" }
            })

            -- change the highlight style
            vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "Visual" })
            vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "Visual" })
            vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "Visual" })

            --- auto update the highlight style on colorscheme change
            vim.api.nvim_create_autocmd({ "ColorScheme" }, {
            pattern = { "*" },
            callback = function(ev)
                vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "Visual" })
                vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "Visual" })
                vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "Visual" })
            end
            })

        end,
    },
    {
        "xiyaowong/virtcolumn.nvim",
        init = function()
            vim.g.virtcolumn_char = " │"
        end
    },
    {
        "folke/zen-mode.nvim",
        keys = {
            { "<leader>tf", "<cmd>ZenMode<cr>", desc = "[T]oggle [F]ocus Mode"}
        },
        opts = {
            plugins = {
                options = {
                    laststatus = 3,
                }
            }
        }
    },
    {
        "utilyre/barbecue.nvim",
        name = "barbecue",
        version = "*",
        dependencies = {
            "SmiteshP/nvim-navic",
            "nvim-tree/nvim-web-devicons"
        },
        opts = {}
    }
}
