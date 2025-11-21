return {
    {
        "hrsh7th/nvim-cmp",
        version = false,
        event = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "onsails/lspkind.nvim",
            "windwp/nvim-autopairs"
        },
        opts = function()
            vim.api.nvim_set_hl(0, "CmpGhostText", { link = "Comment", default = true })
            local cmp = require("cmp")
            local luasnip = require("luasnip")
            return {
                auto_brackets = { "python" },
                completion = {
                    completeopt = "menu,menuone,noinsert,noselect"
                },
                mapping = {
                    ["<Tab>"] = cmp.mapping(function (fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.locally_jumpable(1) then
                            luasnip.jump(1)
                        else
                            fallback()
                        end
                    end, {"i", "s"}),
                    ["<S-Tab>"] = cmp.mapping(function (fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.locally_jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, {"i", "s"}),
                    -- Scroll documentation window [b]ack/[f]orward
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),

                    -- Use Enter to accept the completion
                    ["<CR>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            if luasnip.expandable() then
                                luasnip.expand()
                            else
                                cmp.confirm({
                                    select = true,
                                })
                            end
                        else
                            fallback()
                        end
                    end),

                    -- Manually open and close the completion menu
                    ["<C-Space>"] = cmp.mapping.abort(),
                    ["<C-CR>"] = cmp.mapping.complete(),
                },
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "path" },
                }, {
                    { name= "buffer"}
                }),
                formatting = {
                    fields = { "kind", "abbr", "menu" },
                    format = require("lspkind").cmp_format({
                        mode = "symbol",
                        maxwidth = 50,
                        ellipsis_char = "...",
                        show_labelDetails = true,

                        before = function(entry, vim_item)
                            return vim_item
                        end
                    })
                },
                experimental = {
                    ghost_text = { hl_group = "CmpGhostText" }
                },
            }
        end,

        config = function(_, opts)
            for _, source in ipairs(opts.sources) do
                source.group_index = source.group_index or 1
            end
            local cmp = require("cmp")
            local Kind = cmp.lsp.CompletionItemKind
            cmp.setup(opts)
            cmp.event:on("confirm_done", function(event)
                if not vim.tbl_contains(opts.auto_brackets or {}, vim.bo.filetype) then
                    return
                end
                local entry = event.entry
                local item = entry:get_completion_item()
                if vim.tbl_contains({ Kind.Function, Kind.Method }, item.kind) then
                    local keys = vim.api.nvim_replace_termcodes("()<left>", false, false, true)
                    vim.api.nvim_feedkeys(keys, "i", true)
                end
            end)
        end,
    },
    {
        "L3MON4D3/LuaSnip",
        build = (function()
            if vim.fn.has("win32") == 1 or vim.fn.executable "make" == 0 then
                return
            end
            return "make install_jsregexp"
        end),
        dependencies = {
            {
                "rafamadriz/friendly-snippets",
                config = function()
                    require("luasnip.loaders.from_vscode").lazy_load()
                end,
            },
            {
                "nvim-cmp",
                dependencies = {
                    "saadparwaiz1/cmp_luasnip"
                },

                opts = function(_, opts)
                    opts.snippet = {
                        expand = function(args)
                            require("luasnip").lsp_expand(args.body)
                        end,
                    }
                    table.insert(opts.sources, { name = "luasnip" })
                end,
            },
        },

        opts = {
            history = true,
            delete_check_events = "TextChanged",
        },
        config = function(_, opts)
            -- Highlight groups colourscheme specific
            vim.cmd("hi link LuasnipInsertNodePassive Pmenu")
            vim.cmd("hi link LuasnipSnippetPassive PmenuSel")

            require("luasnip").setup(opts)
        end
    }
}
