return {
  {
    "webhooked/kanso.nvim",
    priority = 1000,
    opts = {
      background = { light = "pearl", dark = "zen" },
      colors = {
        palette = { pearlWhite0 = "#ffffff", zenBg0 = "#181616" },
        theme = {
          pearl = { ui = { bg_gutter = "#ffffff" } },
          zen = { ui = { bg_gutter = "#181616" } },
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "kanso" },
  },
}
