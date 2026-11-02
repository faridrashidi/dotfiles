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
          text = "#242424",
          muted = "#817a8e",
          subtle = "#69647f",
          love = "#a84d68",
          gold = "#b87516",
          rose = "#bf625f",
          pine = "#1f617d",
          foam = "#357e8c",
          iris = "#7c609c",
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
