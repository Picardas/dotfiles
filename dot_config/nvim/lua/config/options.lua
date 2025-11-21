-- Make relative line numbers default
vim.opt.number = true
vim.opt.relativenumber = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Undo persistant undo
vim.opt.undofile = true
vim.opt.undolevels = 10000

-- Enable break indent
vim.opt.breakindent = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Set terminal title
vim.opt.title = true

-- Set completeopt to have a better completion experience
vim.opt.completeopt = 'menuone,noselect'
vim.opt.wildignorecase = true -- ignore filename and directory case
vim.opt.pumblend = 20
vim.opt.wildmode = "full"
vim.opt.wildoptions = "pum"
vim.opt.wildignore = "__pycache__" -- Ignore python compile files
vim.opt.wildignore:append { "*.o", "*.pyc", "*pycache*" } -- And more

-- Partially transparent floating windows
vim.opt.winblend = 20

-- Highlight current line
vim.opt.cursorline = true

-- Keep a number of lines between cursor and end of screen
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8

-- Set default tab behaviour
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true
vim.opt.shiftwidth = 4
vim.opt.shiftround = true

-- Time in ms, if nothing is type, that swap file will be updated (default 4000)
vim.opt.updatetime = 250

-- Time in ms for key sequence to complete (default 1000)
-- vim.opt.timeoutlen = 800

-- Open splits to preference
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Disable "How to disable mouse"
vim.cmd.aunmenu{ "PopUp.How-to\\ disable\\ mouse" }
vim.cmd.aunmenu{ "PopUp.-1-" }

-- Improve wordwrap breaks
vim.opt.linebreak = true

-- Using virtcolumn so line shown after character
vim.opt_local.colorcolumn = "100"

-- Default textwidth, autoformating only comments using formatoptions autocmd
vim.opt_local.textwidth = 100

-- Language for spellchecking
vim.opt.spelllang = { "en_gb" }

-- Use ripgrep for grep and set format
vim.opt.grepprg = "rg --vimgrep"
vim.opt.grepformat = "%f:%l:%c:%m"

-- Allow cursor to move into empty space in block-visual mode
vim.opt.virtualedit = "block"

-- Limit size of completion menu and transparency
vim.opt.pumheight = 10
vim.opt.pumblend = 20

-- Ask to save on before exiting a modified buffer
vim.opt.confirm = true

-- If Windows set pwsh as shell with additional configuration
if vim.fn.has("win32") == 1 then
    vim.opt.shell = "pwsh"
    vim.opt.shellcmdflag = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText;"
    vim.opt.shellredir = "2>&1 | %%{ '$_' } | Out-File %s; exit $LastExitCode"
    vim.opt.shellpipe = "2>&1 | %%{ '$_' } | Tee-Object %s; exit $LastExitCode"
    vim.opt.shellquote = ""
    vim.opt.shellxquote = ""
else
    vim.opt.shell = "bash"
end
