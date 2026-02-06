-- Python Specific Settings
vim.opt_local.colorcolumn = "79"
vim.opt_local.textwidth = 72
vim.opt.wildignore = "__pycache__" -- Ignore python compiled files
vim.opt.wildignore:append { "*.o", "*.pyc", "*pycache*" } -- And more

-- Use treesitter to enable textwidth for text when working on python docstrings, from nvim-cmp
local comment_tw = vim.api.nvim_create_augroup("CommentTextWidth", { clear = true })
vim.api.nvim_create_autocmd("TextChangedI", {
    group = comment_tw,
    callback = function()
        local context = require("cmp.config.context")
        if context.in_treesitter_capture("string.documentation") == true then
            vim.opt_local.formatoptions:append("t")
        else
            vim.opt_local.formatoptions:remove("t")
        end
    end
})
