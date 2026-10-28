-- Run Go tests for the package containing the current buffer.

local M = {}

local state = {
  buf = nil,
  win = nil,
  job = nil,
  run = 0,
}

local function close_previous()
  if state.job and vim.fn.jobwait({ state.job }, 0)[1] == -1 then
    vim.fn.jobstop(state.job)
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  elseif state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf, state.win, state.job = nil, nil, nil
end

function M.run_package()
  local source_win = vim.api.nvim_get_current_win()
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then
    vim.notify('Current buffer has no file path', vim.log.levels.WARN)
    return
  end

  if vim.bo.filetype ~= 'go' then
    vim.notify('Package test runner currently supports Go buffers', vim.log.levels.WARN)
    return
  end

  vim.cmd 'silent update'
  close_previous()

  state.run = state.run + 1
  local run = state.run
  local directory = vim.fs.dirname(path)

  vim.cmd 'botright 12new'
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_get_current_buf()

  vim.bo[state.buf].bufhidden = 'wipe'
  vim.bo[state.buf].buflisted = false
  vim.wo[state.win].winfixheight = true
  vim.wo[state.win].winbar = ' Go test: ' .. directory

  vim.keymap.set('n', 'q', close_previous, {
    buffer = state.buf,
    silent = true,
    desc = 'Close test output',
  })

  state.job = vim.fn.termopen({ 'go', 'test', '.' }, {
    cwd = directory,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if run ~= state.run then
          return
        end
        if state.win and vim.api.nvim_win_is_valid(state.win) then
          local status = exit_code == 0 and '✓ PASS' or '✗ FAIL'
          vim.wo[state.win].winbar = string.format(' %s — go test . — %s', status, directory)
        end
      end)
    end,
  })

  if vim.api.nvim_win_is_valid(source_win) then
    vim.api.nvim_set_current_win(source_win)
  end
end

vim.api.nvim_create_user_command('GoTestPackage', M.run_package, {
  desc = 'Run tests for the Go package containing the current buffer',
})

vim.keymap.set('n', '<leader>w', M.run_package, {
  silent = true,
  desc = 'Run Go package tests',
})

return M
