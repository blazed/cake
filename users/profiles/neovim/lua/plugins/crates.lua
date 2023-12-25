local M = {}

function M.setup()
  require("crates").setup()
end

function M.keymaps()
  K.map { "<leader>cv", "Crates: Versions popup", require("crates").show_versions_popup, mode = "n" }
  K.map { "<leader>cf", "Crates: Features popup", require("crates").show_features_popup, mode = "n" }
end

return M
