-- Loaded before init.lua, then run after startup. Two processes ensure plugin
-- upgrades are verified with freshly loaded code rather than cached Lua modules.
local errors = {}
local notify = vim.notify
vim.notify = function(message, level, opts)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = tostring(message) end
  return notify(message, level, opts)
end
vim.defer_fn(function()
  io.stderr:write('Neovim provisioning timed out after 15 minutes\n')
  vim.cmd('cquit 1')
end, 15 * 60 * 1000)

local function read_pins()
  return vim.json.decode(table.concat(vim.fn.readfile(vim.env.DOTFILES_NVIM_ROOT .. '/.config/nvim/lazy-lock.json'), '\n'))
end

local function head(dir)
  local result = vim.fn.system({ 'git', '-C', dir, 'rev-parse', 'HEAD' })
  assert(vim.v.shell_error == 0, 'Cannot read plugin revision: ' .. dir)
  return vim.trim(result)
end

local function check_tasks(plugins)
  for name, plugin in pairs(plugins) do
    for _, task in ipairs(plugin._.tasks or {}) do
      assert(not task:has_errors(), 'Plugin install/build failed: ' .. name)
    end
  end
end

local function provision_plugins()
  local lazy = require('lazy')
  local config = require('lazy.core.config')
  local lock = require('lazy.manage.lock')
  local pins = read_pins()
  -- Startup may have installed missing plugins and rewritten its disposable
  -- lock. Reapply the source pins, including when an older plugin already exists.
  lock.lock, lock._loaded = vim.deepcopy(pins), true
  lazy.install({ wait = true, show = false, lockfile = true })
  check_tasks(config.plugins)
  lock.lock = vim.deepcopy(pins)
  local drift = {}
  for name, pin in pairs(pins) do
    local plugin = assert(config.plugins[name], 'Pinned plugin missing from config: ' .. name)
    if head(plugin.dir) ~= pin.commit then drift[#drift + 1] = name end
  end
  if #drift > 0 then lazy.restore({ plugins = drift, wait = true, show = false }) end
  check_tasks(config.plugins)
  for name, pin in pairs(pins) do
    assert(head(config.plugins[name].dir) == pin.commit, 'Plugin pin mismatch: ' .. name)
  end
  print('Pinned plugins verified: ' .. vim.tbl_count(pins))
end

local function verify()
  local lazy = require('lazy')
  lazy.load({ plugins = { 'telescope.nvim', 'bufferline.nvim', 'which-key.nvim', 'conform.nvim' } })
  require('telescope').load_extension('fzf')
  assert(vim.g.colors_name == 'tokyonight-night', 'Theme did not load')
  assert(vim.g.mapleader == ' ', 'Space leader missing')
  assert(package.loaded['custom.notes'], 'Custom notes module did not load')
  assert(package.loaded['custom.test_runner'], 'Custom test runner did not load')
  for _, command in ipairs({ 'Neotree', 'Telescope', 'BufferLineCycleNext', 'Today', 'Mason' }) do
    assert(vim.fn.exists(':' .. command) == 2, 'Missing command: ' .. command)
  end
  for _, key in ipairs({ '<leader>sf', '<leader>nt', '<leader>bp', '<leader>cc' }) do
    assert(next(vim.fn.maparg(key, 'n', false, true)), 'Missing mapping: ' .. key)
  end

  -- Use the configured Mason list; init.lua adds gopls only when PATH lacks it.
  vim.cmd('MasonToolsInstallSync')
  for _, tool in ipairs({ 'gopls', 'rust-analyzer', 'lua-language-server', 'stylua', 'jdtls' }) do
    assert(vim.fn.executable(tool) == 1, 'Missing language tool: ' .. tool)
  end
  vim.fn.system({ 'gopls', 'version' })
  assert(vim.v.shell_error == 0, 'gopls cannot execute on this machine')

  local parsers = require('nvim-treesitter.configs').get_ensure_installed_parsers()
  parsers = vim.list_extend(vim.deepcopy(parsers), { 'go', 'gomod', 'gowork', 'rust', 'java' })
  local missing = {}
  for _, parser in ipairs(parsers) do
    local ok, loaded = pcall(vim.treesitter.language.add, parser)
    if not ok or not loaded then missing[#missing + 1] = parser end
  end
  -- Plain TSInstallSync prompts when a parser exists. Only repair missing/broken
  -- parsers and use ! so repeat provisioning can never wait for terminal input.
  if #missing > 0 then vim.cmd('TSInstallSync! ' .. table.concat(missing, ' ')) end
  for _, parser in ipairs(parsers) do
    assert(vim.treesitter.language.add(parser), 'Parser could not load: ' .. parser)
  end
  check_tasks(require('lazy.core.config').plugins)
  assert(vim.v.errmsg == '', 'Startup error: ' .. vim.v.errmsg)
  assert(#errors == 0, table.concat(errors, '\n'))
  print('PASS: theme, custom modules/mappings, native fzf, language tools and parsers')
end

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.schedule(function()
      local ok, err = xpcall(function()
        assert(vim.fn.has('nvim-0.11.3') == 1, 'This plugin snapshot requires Neovim 0.11.3 or newer')
        if vim.env.DOTFILES_NVIM_PHASE == 'plugins' then provision_plugins()
        elseif vim.env.DOTFILES_NVIM_PHASE == 'verify' then verify()
        else error('Unknown Neovim provisioning phase') end
        assert(vim.fn.writefile({ 'verified' }, vim.env.DOTFILES_NVIM_SUCCESSFILE) == 0)
      end, debug.traceback)
      if not ok then
        io.stderr:write(err .. '\n')
        vim.cmd('cquit 1')
      else
        vim.cmd('qa!')
      end
    end)
  end,
})
