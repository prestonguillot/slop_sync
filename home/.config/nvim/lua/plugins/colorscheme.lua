return {
  {
    "sainnhe/sonokai",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.sonokai_style = "andromeda"
      vim.g.sonokai_better_performance = 1
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "sonokai",
    },
  },
}