-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

-- Load personal keymaps/logic that aren't plugins
pcall(require, 'custom.terminal')

return {
  -- Buffer visualization with tabs
  {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VimEnter',
    opts = {
      options = {
        mode = "buffers",
        separator_style = "slant",
        always_show_bufferline = true,
        show_buffer_close_icons = true,
        show_close_icon = true,
        color_icons = true,
        diagnostics = "nvim_lsp",
        diagnostics_update_in_insert = false,
        offsets = {
          {
            filetype = "neo-tree",
            text = "File Explorer",
            text_align = "center",
            separator = true,
          },
        },
      },
    },
    keys = {
      { '<leader>bp', '<cmd>BufferLineTogglePin<cr>', desc = 'Toggle pin' },
      { '<leader>bP', '<cmd>BufferLineGroupClose ungrouped<cr>', desc = 'Delete non-pinned buffers' },
      { '<leader>bo', '<cmd>BufferLineCloseOthers<cr>', desc = 'Delete other buffers' },
      { '<leader>br', '<cmd>BufferLineCloseRight<cr>', desc = 'Delete buffers to the right' },
      { '<leader>bl', '<cmd>BufferLineCloseLeft<cr>', desc = 'Delete buffers to the left' },
      { '[b', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev buffer' },
      { ']b', '<cmd>BufferLineCycleNext<cr>', desc = 'Next buffer' },
    },
  },

  -- Git blame functionality with inline blame
  {
    'f-person/git-blame.nvim',
    event = 'VeryLazy',
    opts = {
      enabled = true,
      message_template = ' <summary> • <date> • <author>',
      date_format = '%m-%d-%Y %H:%M:%S',
      virtual_text_column = 1,
      highlight_group = 'Question',
      delay = 1000,
      ignored_filetypes = {},
    },
    keys = {
      { '<leader>gb', '<cmd>GitBlameToggle<cr>', desc = 'Toggle git blame' },
      { '<leader>go', '<cmd>GitBlameOpenCommitURL<cr>', desc = 'Open commit URL' },
      { '<leader>gc', '<cmd>GitBlameCopySHA<cr>', desc = 'Copy commit SHA' },
      { '<leader>gf', '<cmd>GitBlameOpenFileURL<cr>', desc = 'Open file URL' },
    },
  },

  -- Enhanced gitsigns with better git integration
  {
    'lewis6991/gitsigns.nvim',
    event = 'VimEnter',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then return ']c' end
          vim.schedule(function() gs.next_hunk() end)
          return '<Ignore>'
        end, {expr=true, desc = 'Next git hunk'})

        map('n', '[c', function()
          if vim.wo.diff then return '[c' end
          vim.schedule(function() gs.prev_hunk() end)
          return '<Ignore>'
        end, {expr=true, desc = 'Previous git hunk'})

        -- Actions
        map('n', '<leader>hs', gs.stage_hunk, { desc = 'Stage hunk' })
        map('n', '<leader>hr', gs.reset_hunk, { desc = 'Reset hunk' })
        map('v', '<leader>hs', function() gs.stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = 'Stage hunk' })
        map('v', '<leader>hr', function() gs.reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = 'Reset hunk' })
        map('n', '<leader>hS', gs.stage_buffer, { desc = 'Stage buffer' })
        map('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'Undo stage hunk' })
        map('n', '<leader>hR', gs.reset_buffer, { desc = 'Reset buffer' })
        map('n', '<leader>hp', gs.preview_hunk, { desc = 'Preview hunk' })
        map('n', '<leader>hb', function() gs.blame_line{full=true} end, { desc = 'Blame line' })
        map('n', '<leader>hd', gs.diffthis, { desc = 'Diff this' })
        map('n', '<leader>hD', function() gs.diffthis('~') end, { desc = 'Diff this ~' })

        -- Text object
        map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'Select hunk' })
      end
    },
  },

  -- Octo.nvim for GitHub PR review and management
  {
    'pwntester/octo.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    cmd = 'Octo',
    config = function()
      require('octo').setup({
        enable_builtin = true,
        default_to_projects_v2 = true,
        default_merge_method = 'squash',
        picker = 'telescope',
        mappings = {
          pull_request = {
            checkout_pr = { lhs = '<localleader>po', desc = 'checkout PR' },
            merge_pr = { lhs = '<localleader>pm', desc = 'merge commit PR' },
            squash_and_merge_pr = { lhs = '<localleader>psm', desc = 'squash and merge PR' },
            rebase_and_merge_pr = { lhs = '<localleader>prm', desc = 'rebase and merge PR' },
            list_commits = { lhs = '<localleader>pc', desc = 'list PR commits' },
            list_changed_files = { lhs = '<localleader>pf', desc = 'list PR changed files' },
            show_pr_diff = { lhs = '<localleader>pd', desc = 'show PR diff' },
            add_reviewer = { lhs = '<localleader>va', desc = 'add reviewer' },
            remove_reviewer = { lhs = '<localleader>vd', desc = 'remove reviewer' },
            close_issue = { lhs = '<localleader>ic', desc = 'close PR' },
            reopen_issue = { lhs = '<localleader>io', desc = 'reopen PR' },
            list_issues = { lhs = '<localleader>il', desc = 'list open issues' },
            reload = { lhs = '<C-r>', desc = 'reload PR' },
            open_in_browser = { lhs = '<C-b>', desc = 'open PR in browser' },
            copy_url = { lhs = '<C-y>', desc = 'copy url to system clipboard' },
            goto_file = { lhs = 'gf', desc = 'go to file' },
            add_assignee = { lhs = '<localleader>aa', desc = 'add assignee' },
            remove_assignee = { lhs = '<localleader>ad', desc = 'remove assignee' },
            create_label = { lhs = '<localleader>lc', desc = 'create label' },
            add_label = { lhs = '<localleader>la', desc = 'add label' },
            remove_label = { lhs = '<localleader>ld', desc = 'remove label' },
            goto_issue = { lhs = '<localleader>gi', desc = 'navigate to a local repo issue' },
            add_comment = { lhs = '<localleader>ca', desc = 'add comment' },
            delete_comment = { lhs = '<localleader>cd', desc = 'delete comment' },
            next_comment = { lhs = ']c', desc = 'go to next comment' },
            prev_comment = { lhs = '[c', desc = 'go to previous comment' },
            react_hooray = { lhs = '<localleader>rp', desc = 'add/remove 🎉 reaction' },
            react_heart = { lhs = '<localleader>rh', desc = 'add/remove ❤️ reaction' },
            react_eyes = { lhs = '<localleader>re', desc = 'add/remove 👀 reaction' },
            react_thumbs_up = { lhs = '<localleader>r+', desc = 'add/remove 👍 reaction' },
            react_thumbs_down = { lhs = '<localleader>r-', desc = 'add/remove 👎 reaction' },
            react_rocket = { lhs = '<localleader>rr', desc = 'add/remove 🚀 reaction' },
            react_laugh = { lhs = '<localleader>rl', desc = 'add/remove 😄 reaction' },
            react_confused = { lhs = '<localleader>rc', desc = 'add/remove 😕 reaction' },
          },
          review_thread = {
            goto_issue = { lhs = '<localleader>gi', desc = 'navigate to a local repo issue' },
            add_comment = { lhs = '<localleader>ca', desc = 'add comment' },
            add_suggestion = { lhs = '<localleader>sa', desc = 'add suggestion' },
            delete_comment = { lhs = '<localleader>cd', desc = 'delete comment' },
            next_comment = { lhs = ']t', desc = 'go to next comment' },
            prev_comment = { lhs = '[t', desc = 'go to previous comment' },
            select_next_entry = { lhs = ']q', desc = 'move to previous changed file' },
            select_prev_entry = { lhs = '[q', desc = 'move to next changed file' },
            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
            react_hooray = { lhs = '<localleader>rp', desc = 'add/remove 🎉 reaction' },
            react_heart = { lhs = '<localleader>rh', desc = 'add/remove ❤️ reaction' },
            react_eyes = { lhs = '<localleader>re', desc = 'add/remove 👀 reaction' },
            react_thumbs_up = { lhs = '<localleader>r+', desc = 'add/remove 👍 reaction' },
            react_thumbs_down = { lhs = '<localleader>r-', desc = 'add/remove 👎 reaction' },
            react_rocket = { lhs = '<localleader>rr', desc = 'add/remove 🚀 reaction' },
            react_laugh = { lhs = '<localleader>rl', desc = 'add/remove 😄 reaction' },
            react_confused = { lhs = '<localleader>rc', desc = 'add/remove 😕 reaction' },
          },
          submit_win = {
            approve_review = { lhs = '<C-a>', desc = 'approve review' },
            comment_review = { lhs = '<C-m>', desc = 'comment review' },
            request_changes = { lhs = '<C-r>', desc = 'request changes review' },
            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
          },
          review_diff = {
            add_review_comment = { lhs = '<localleader>ca', desc = 'add a new review comment' },
            add_review_suggestion = { lhs = '<localleader>sa', desc = 'add a new review suggestion' },
            focus_files = { lhs = '<localleader>e', desc = 'move focus to changed file panel' },
            toggle_files = { lhs = '<localleader>b', desc = 'hide/show changed files panel' },
            next_thread = { lhs = ']t', desc = 'move to next thread' },
            prev_thread = { lhs = '[t', desc = 'move to previous thread' },
            select_next_entry = { lhs = ']q', desc = 'move to previous changed file' },
            select_prev_entry = { lhs = '[q', desc = 'move to next changed file' },
            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
            toggle_viewed = { lhs = '<localleader><space>', desc = 'toggle viewer viewed state' },
            goto_file = { lhs = 'gf', desc = 'go to file' },
          },
          file_panel = {
            next_entry = { lhs = 'j', desc = 'move to next changed file' },
            prev_entry = { lhs = 'k', desc = 'move to previous changed file' },
            select_entry = { lhs = '<cr>', desc = 'show selected changed file diffs' },
            refresh_files = { lhs = 'R', desc = 'refresh changed files panel' },
            focus_files = { lhs = '<localleader>e', desc = 'move focus to changed file panel' },
            toggle_files = { lhs = '<localleader>b', desc = 'hide/show changed files panel' },
            select_next_entry = { lhs = ']q', desc = 'move to previous changed file' },
            select_prev_entry = { lhs = '[q', desc = 'move to next changed file' },
            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
            toggle_viewed = { lhs = '<localleader><space>', desc = 'toggle viewer viewed state' },
          },
        },
      })
    end,
    keys = {
      -- Direct PR access (best for monorepos)
      { '<leader>on', function()
          vim.ui.input({ prompt = 'PR number: ' }, function(input)
            if input then
              vim.cmd('Octo pr edit ' .. input)
            end
          end)
        end, desc = 'Open PR by number' },
      { '<leader>ou', '<cmd>Octo pr url<cr>', desc = 'Open PR from URL' },
      { '<leader>ox', '<cmd>Octo search<cr>', desc = 'Search PRs/issues' },

      -- PR workflow commands
      { '<leader>oc', '<cmd>Octo pr checkout<cr>', desc = 'Checkout PR' },
      { '<leader>od', '<cmd>Octo pr diff<cr>', desc = 'Show PR diff' },
      { '<leader>or', '<cmd>Octo review start<cr>', desc = 'Start review' },
      { '<leader>os', '<cmd>Octo review resume<cr>', desc = 'Resume review' },
      { '<leader>ob', '<cmd>Octo pr browser<cr>', desc = 'Open PR in browser' },
      { '<leader>om', '<cmd>Octo pr merge squash<cr>', desc = 'Merge PR (squash)' },
      { '<leader>ol', '<cmd>Octo pr commits<cr>', desc = 'List PR commits' },
      { '<leader>of', '<cmd>Octo pr changes<cr>', desc = 'List PR changed files' },

      -- Custom PR commands for CI/CD
      { '<leader>ois', function()
          vim.cmd('Octo comment add')
          vim.schedule(function()
            -- Enter insert mode and type the command
            vim.api.nvim_feedkeys('i/integrate -d', 'n', false)
          end)
        end, desc = 'Integrate staging (/integrate -d)' },
      { '<leader>omp', function()
          vim.cmd('Octo comment add')
          vim.schedule(function()
            -- Enter insert mode and type the command
            vim.api.nvim_feedkeys('i/merge', 'n', false)
          end)
        end, desc = 'Merge to prod (/merge)' },

      -- Personalized PR lists
      { '<leader>op', '<cmd>Octo pr list assignee=alexanderbianchi author=alexanderbianchi<cr>', desc = 'My PRs (assigned or authored)' },
      { '<leader>oa', '<cmd>Octo pr list assignee=alexanderbianchi<cr>', desc = 'PRs assigned to me' },
      { '<leader>ow', '<cmd>Octo pr list author=alexanderbianchi<cr>', desc = 'PRs I authored' },
      { '<leader>oq', function()
          vim.ui.input({ prompt = 'Filter (e.g., author=username, label=bug): ' }, function(input)
            local filter = input and input ~= '' and ' ' .. input or ''
            vim.cmd('Octo pr list' .. filter)
          end)
        end, desc = 'Custom PR filter' },

      -- Less common
      { '<leader>oe', '<cmd>Octo pr create<cr>', desc = 'Create PR' },
      { '<leader>oi', '<cmd>Octo issue list<cr>', desc = 'List issues' },
    },
  },

  -- Claude Code integration for live buffer updates and chat
  {
    'greggh/claude-code.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    config = function()
      require('claude-code').setup({
        window = {
          position = 'vertical',  -- Opens vertically instead of horizontal
          split_ratio = 0.4,      -- 40% of screen width
          enter_insert = true,    -- Auto-enter insert mode when opened
        },
      })
    end,
    keys = {
      { '<leader>cc', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude Code' },
      { '<leader>cr', '<cmd>ClaudeCodeResume<cr>', desc = 'Resume conversation' },
      { '<leader>cn', '<cmd>ClaudeCodeContinue<cr>', desc = 'Continue conversation' },
      { '<leader>cv', '<cmd>ClaudeCodeVerbose<cr>', desc = 'Toggle verbose logging' },
    },
  },
}
