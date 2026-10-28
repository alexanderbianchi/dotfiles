-- Personal notes vault helpers (~/personal)
-- Keymaps under <leader>n. Plugin config lives in custom/plugins/init.lua.

local vault = vim.fn.expand '~/personal'

local function open_today()
  local path = vault .. '/journal/' .. os.date '%Y-%m-%d' .. '.md'
  if vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(vault .. '/journal', 'p')
    vim.fn.writefile({
      '# ' .. os.date '%Y-%m-%d',
      '',
      '## Notes',
      '',
      '## Tasks',
      '',
      '## Links',
      '',
    }, path)
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

vim.api.nvim_create_user_command('Today', open_today, { desc = "Open today's journal" })

local function find_notes()
  require('telescope.builtin').find_files { cwd = vault, prompt_title = 'Notes' }
end

local function grep_notes()
  require('telescope.builtin').live_grep { cwd = vault, prompt_title = 'Grep notes' }
end

local function find_by_tag()
  vim.ui.input({ prompt = 'tag: #' }, function(tag)
    if not tag or tag == '' then
      return
    end
    require('telescope.builtin').grep_string {
      cwd = vault,
      search = '#' .. tag,
      use_regex = false,
      prompt_title = 'tag: #' .. tag,
    }
  end)
end

local function open_todo()
  vim.cmd('edit ' .. vim.fn.fnameescape(vault .. '/TODO'))
end

vim.keymap.set('n', '<leader>nt', open_today, { desc = '[N]otes: [T]oday' })
vim.keymap.set('n', '<leader>nf', find_notes, { desc = '[N]otes: [F]ind file' })
vim.keymap.set('n', '<leader>ng', grep_notes, { desc = '[N]otes: [G]rep' })
vim.keymap.set('n', '<leader>n#', find_by_tag, { desc = '[N]otes: by tag' })
vim.keymap.set('n', '<leader>nd', open_todo, { desc = '[N]otes: TO[D]O' })
