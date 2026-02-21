-- custom/terminal.lua
-- Enhanced NVChad-like terminal functionality

local map = vim.keymap.set
local opts = { silent = true }

-- Terminal state management
local terminals = {}

-- Function to create or toggle terminal
local function create_or_toggle_terminal(type_key, split_cmd)
  if terminals[type_key] and vim.api.nvim_buf_is_valid(terminals[type_key].buf) then
    local wins = vim.fn.win_findbuf(terminals[type_key].buf)
    if #wins > 0 then
      -- Terminal is visible, hide it
      vim.api.nvim_win_close(wins[1], false)
    else
      -- Terminal exists but not visible, show it
      vim.cmd(split_cmd)
      vim.api.nvim_set_current_buf(terminals[type_key].buf)
      vim.cmd 'startinsert'
    end
  else
    -- Create new terminal
    vim.cmd(split_cmd .. ' | terminal')
    terminals[type_key] = {
      buf = vim.api.nvim_get_current_buf(),
      job = vim.b.terminal_job_id,
    }
    vim.cmd 'startinsert'
  end
end

-- Enhanced terminal keymaps with toggle functionality
map('n', '<leader>th', function()
  create_or_toggle_terminal('horizontal', 'split')
end, { desc = 'Toggle horizontal terminal' })

map('n', '<leader>tv', function()
  create_or_toggle_terminal('vertical', 'vsplit')
end, { desc = 'Toggle vertical terminal' })


-- Enhanced floating terminal with toggle functionality
map('n', '<leader>tf', function()
  if terminals['float'] and vim.api.nvim_buf_is_valid(terminals['float'].buf) then
    local wins = vim.fn.win_findbuf(terminals['float'].buf)
    if #wins > 0 then
      -- Float is visible, close it
      vim.api.nvim_win_close(wins[1], false)
    else
      -- Float exists but not visible, show it
      local width = math.floor(vim.o.columns * 0.9)
      local height = math.floor(vim.o.lines * 0.8)
      local row = math.floor((vim.o.lines - height) / 2 - 1)
      local col = math.floor((vim.o.columns - width) / 2)
      local win = vim.api.nvim_open_win(terminals['float'].buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
      })
      terminals['float'].win = win
      vim.cmd 'startinsert'
    end
  else
    -- Create new floating terminal
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2 - 1)
    local col = math.floor((vim.o.columns - width) / 2)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
    })
    vim.fn.termopen(vim.o.shell)
    terminals['float'] = {
      buf = buf,
      win = win,
      job = vim.b.terminal_job_id,
    }
    vim.cmd 'startinsert'

    -- ESC twice to close float
    vim.keymap.set('t', '<ESC><ESC>', function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, silent = true })

    -- q in normal mode to close the float
    vim.keymap.set('n', 'q', function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, silent = true })
  end
end, { desc = 'Toggle floating terminal' })

-- Terminal + Claude command
map('n', '<leader>tc', function()
  -- First open terminal horizontally
  create_or_toggle_terminal('horizontal', 'split')
  
  -- Then open Claude vertically to the right
  vim.cmd('vsplit')
  vim.cmd('terminal claude code')
  vim.cmd('startinsert')
end, { desc = 'Open terminal + Claude vertically' })

-- Terminal-mode quality of life: Esc leaves insert; <C-h/j/k/l> moves between splits
map('t', '<Esc>', [[<C-\><C-n>]], opts)
map('t', '<C-h>', [[<C-\><C-n><C-w>h]], opts)
map('t', '<C-j>', [[<C-\><C-n><C-w>j]], opts)
map('t', '<C-k>', [[<C-\><C-n><C-w>k]], opts)
map('t', '<C-l>', [[<C-\><C-n><C-w>l]], opts)

-- (Optional) use macOS clipboard by default when yanking
vim.opt.clipboard = 'unnamedplus'
--

-- Minimal sender: <leader>sl sends current line, <leader>ss sends visual selection
local term = { buf = nil, job = nil }
local function ensure_term()
  if term.job and vim.fn.jobwait({ term.job }, 0)[1] == -1 and vim.api.nvim_buf_is_valid(term.buf) then
    return
  end
  vim.cmd 'vsplit | terminal'
  term.buf = vim.api.nvim_get_current_buf()
  term.job = vim.b.terminal_job_id
  vim.cmd 'startinsert'
end

local function send(text)
  ensure_term()
  if type(text) == 'table' then
    text = table.concat(text, '\n')
  end
  if not text:match '\n$' then
    text = text .. '\n'
  end
  vim.fn.chansend(term.job, text)
end

vim.keymap.set('n', '<leader>sl', function()
  send(vim.api.nvim_get_current_line())
end, { desc = 'Send line to terminal' })

vim.keymap.set('v', '<leader>ss', function()
  local s = vim.api.nvim_buf_get_mark(0, '<')
  local e = vim.api.nvim_buf_get_mark(0, '>')
  local lines = vim.api.nvim_buf_get_lines(0, s[1] - 1, e[1], false)
  if #lines > 0 then
    local scol = s[2] + 1
    local ecol = e[2] + 1
    if #lines == 1 then
      lines[1] = string.sub(lines[1], scol, ecol)
    else
      lines[1] = string.sub(lines[1], scol)
      lines[#lines] = string.sub(lines[#lines], 1, ecol)
    end
  end
  send(lines)
end, { desc = 'Send selection to terminal' })

-- ── Which-key labels so they appear in the <space> help ──────────────────────
-- Kickstart ships with folke/which-key.nvim; register names & descriptions
local ok_wk, wk = pcall(require, 'which-key')
if ok_wk then
  wk.add {
    { '<leader>t', group = 'Terminal' },
    { '<leader>th', desc = 'Toggle horizontal terminal' },
    { '<leader>tv', desc = 'Toggle vertical terminal' },
    { '<leader>tf', desc = 'Toggle floating terminal' },
    { '<leader>tc', desc = 'Open terminal + Claude vertically' },
    { '<leader>s', group = 'Send to Terminal' },
    { '<leader>sl', desc = 'Send line' },
    { '<leader>ss', desc = 'Send selection' },
  }
end
