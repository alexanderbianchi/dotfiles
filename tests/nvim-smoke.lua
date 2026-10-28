-- Run with HOME set to a temporary directory and a stub `go` on PATH:
-- DOTFILES_ROOT=/path/to/dotfiles nvim --headless -u NONE -l tests/nvim-smoke.lua
local root = assert(vim.env.DOTFILES_ROOT)
for _, file in ipairs(vim.fn.glob(root .. '/.config/nvim/**/*.lua', false, true)) do
  assert(loadfile(file), 'Lua syntax error: ' .. file)
end
package.path = root .. '/.config/nvim/lua/?.lua;' .. package.path
require 'custom.notes'
vim.cmd 'Today'
assert(vim.api.nvim_buf_get_name(0):match('/personal/journal/%d%d%d%d%-%d%d%-%d%d%.md$'))
assert(vim.fn.filereadable(vim.api.nvim_buf_get_name(0)) == 1)

local gofile = vim.env.HOME .. '/example.go'
vim.fn.writefile({ 'package example' }, gofile)
vim.cmd('edit ' .. vim.fn.fnameescape(gofile))
vim.bo.filetype = 'go'
require('custom.test_runner').run_package()
assert(vim.wait(5000, function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.wo[win].winbar:find('PASS', 1, true) then return true end
  end
  return false
end), 'Go test output did not report PASS')
print('Neovim syntax, journal creation, and test-runner smoke checks passed')
vim.cmd 'qa!'
