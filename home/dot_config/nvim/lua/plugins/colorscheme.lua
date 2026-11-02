return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 1000,
    opts = {
      variant = "auto",
      dark_variant = "main",
      palette = {
        dawn = {
          base = "#ffffff",
          surface = "#f5f5f5",
          overlay = "#eeeeee",
          _nc = "#f5f5f5",
          highlight_low = "#f5f5f5",
          highlight_med = "#e5e5e5",
          highlight_high = "#dddddd",
        },
      },
      highlight_groups = {
        -- Keep comments readable in both variants.
        Comment = { fg = "subtle" },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },
}
