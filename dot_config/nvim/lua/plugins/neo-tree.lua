return {
  "nvim-neo-tree/neo-tree.nvim",

  config = function(_, opts)
    local is_git_file_event = false
    local prev_filetype = ""

    vim.api.nvim_create_autocmd("User", {
      pattern = {
        "NeogitStatusRefreshed",
      },
      callback = function()
        is_git_file_event = true
      end,
    })
    vim.api.nvim_create_autocmd("TabLeave", {
      callback = function()
        prev_filetype = vim.api.nvim_get_option_value("filetype", {})
      end,
    })
    vim.api.nvim_create_autocmd("TabEnter", {
      callback = function()
        if vim.startswith(prev_filetype, "Neogit") and is_git_file_event then
          require("neo-tree.events").fire_event("git_event")
          is_git_file_event = false
        end
      end,
    })

    require("neo-tree").setup(opts)
  end,
}
