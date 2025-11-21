return {
    {
        -- Lspconfig
        "neovim/nvim-lspconfig",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            {
                "williamboman/mason.nvim",
                cmd = "Mason",
                build = ":MasonUpdate",
                config = true
            },
            { "williamboman/mason-lspconfig.nvim" },
            { "j-hui/fidget.nvim", config = true },
            { "folke/neodev.nvim", config = true }
        },

        config = function()
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("Lsp-Attach", { clear = true} ),
                callback = function(event)
                    local map = function(keys, func, desc)
                        vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc } )
                    end

                    -- Jump to definition of word under cursor
                    -- Use <C-t> to go back
                    map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
                    -- Find references for word under cursor
                    map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
                    -- Jump to implemtation of word under cursor
                    map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
                    -- Jump to type of word under cursor
                    map("gT", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")
                    -- Find all symbols in document
                    map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
                    -- Find all symbols in workspace
                    map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
                    --- Rename variable under cursor
                    map("<leader>rn", vim.lsp.buf.rename, "[R]e[N]ame")
                    -- Execute code action - Cursor should be on error or language server suggestion
                    map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
                    -- Pop-up documentation for word under cursor
                    map("K", vim.lsp.buf.hover, "Hover Documentation")
                    -- Jump to Declaration - NOT Definition
                    map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
                    -- Manage workspace folders
                    map("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
                    map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
                    map("<leader>wl", function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, "[W]orkspace [L]ist Folders")

                end,
            })

            local capabilities = vim.lsp.protocol.make_client_capabilities()
            local workspace_capabilities = {
                workspace = {
                    fileOperations = {
                        didRename = true,
                        willRename = true
                    }
                }
            }
            capabilities = vim.tbl_deep_extend("force", capabilities, workspace_capabilities, require("cmp_nvim_lsp").default_capabilities())

            local servers = {
                lua_ls = {
                    settings = {
                        Lua = {
                            completion = {
                                callSnippet = "Replace",
                            }
                        }
                    }
                },
                basedpyright = {
                    settings = {
                        basedpyright = {
                            analysis = {
                                typeCheckingMode = "standard"
                            }
                        }
                    }
                },
                powershell_es = {}
            }

            require("mason-lspconfig").setup({
                ensure_installed = vim.tbl_keys(servers or {}),
                diagnostics = {
                    underline = true,
                    update_in_insert = false,
                    virtual_text = {
                        spacing = 4,
                        source = "if_many",
                        prefix = "●"
                    },
                    severity_sort = true,
                },
                inlay_hints = {
                    enabled = true,
                    exclude = {}
                },
                codelens = {
                    enabled = true
                },
                handlers = {
                    function(server_name)
                        local server = servers[server_name] or {}
                        server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
                        require("lspconfig")[server_name].setup(server)
                    end,
                }
            })

            local signs = {
                Error = " ",
                Warn = " ",
                Hint = " ",
                Info = " "
            }
            for type, icon in pairs(signs) do
                local hl = "DiagnosticSign" .. type
                vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
            end

        end,
    },
}
