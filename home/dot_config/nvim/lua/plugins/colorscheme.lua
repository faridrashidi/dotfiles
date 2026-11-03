local function apply_theme()
  local light = vim.o.background == "light"
  local name = light and "github_light_default" or "kanagawa"
  if vim.g.colors_name ~= name then
    vim.cmd.colorscheme(light and "github_light_default" or "kanagawa-dragon")
  end
end

return {
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    priority = 1000,
    opts = {},
  },
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    opts = { theme = "dragon" },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        vim.api.nvim_create_autocmd("OptionSet", {
          pattern = "background",
          group = vim.api.nvim_create_augroup("DotfilesTheme", { clear = true }),
          callback = function()
            vim.schedule(apply_theme)
          end,
        })
        apply_theme()
      end,
    },
  },
}
