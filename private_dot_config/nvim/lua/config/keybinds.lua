-- [[ Wild Menu Keybinds ]]

-- Enter to accept command line completions
vim.keymap.set("c", "<CR>", function()
    if vim.fn.pumvisible() == 1 then return "<C-y>" end
    return "<CR>"
    end, { expr = true })

-- Swap behaviour or up/down and left/right
vim.keymap.set("c", "<Up>", function()
    if vim.fn.pumvisible() == 1 then return "<Left>" end
    return "<Up>"
    end, { expr = true })

vim.keymap.set("c", "<Down>", function()
    if vim.fn.pumvisible() == 1 then return "<Right>" end
    return "<Down>"
    end, { expr = true })

vim.keymap.set("c", "<Right>", function()
    if vim.fn.pumvisible() == 1 then return "<Down>" end
    return "<Right>"
    end, { expr = true })

vim.keymap.set("c", "<Left>", function()
    if vim.fn.pumvisible() == 1 then return "<Up>" end
    return "<Left>"
    end, { expr = true })
