{
  config,
  pkgs,
  ...
}:
{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
      MANPAGER = "nvim -c 'set ft=man bt=nowrite noswapfile nobk shada=\\\"NONE\\\" ro noma' +Man! -o -";
    };
    packages = [ pkgs.nvrh ];
  };

  programs.lazyvim = {
    enable = true;

    extras = {
      lang.nix.enable = true;
      lang.rust = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.go = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.typescript = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
        biome.enable = true;
      };
      lang.docker = {
        enable = true;
        installDependencies = true;
      };
      lang.dotnet = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.helm = {
        enable = true;
        installDependencies = true;
      };
      lang.json = {
        enable = true;
        installDependencies = true;
      };
      lang.markdown.enable = true;
      lang.nushell.enable = true;
      lang.sql = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.tailwind = {
        enable = true;
        installDependencies = true;
      };
      lang.terraform = {
        enable = true;
        installDependencies = true;
      };
      lang.toml = {
        enable = true;
        installDependencies = true;
      };
      lang.yaml = {
        enable = true;
        installDependencies = true;
      };
    };

    extraPackages = with pkgs; [
      bash-language-server
      docker-compose-language-service
      dockerfile-language-server
      helm-ls
      lua-language-server
      nixd
      nixfmt
      jq
      isort
      ruff
      shfmt
      sqls
      statix
      stylelint
      stylua
      tailwindcss-language-server
      terraform-ls
      typos-lsp
      vscode-langservers-extracted
      yamlfmt
      yaml-language-server
    ];

    plugins.lsp = ''
      return {
        {
          "neovim/nvim-lspconfig",
          opts = {
            servers = {
              bashls = {},
              biome = {},
              cssls = {},
              docker_compose_language_service = {},
              dockerls = {},
              fsautocomplete = {},
              helm_ls = {},
              html = {},
              jsonls = {},
              lua_ls = {},
              nixd = {
                settings = {
                  nixpkgs = { expr = "import <nixpkgs> {}" },
                  formatting = { command = { "nixfmt" } },
                },
              },
              nil_ls = { enabled = false },
              nushell = {},
              sqls = {},
              statix = {},
              tailwindcss = {},
              terraformls = { filetypes = { "terraform", "tf", "hcl" } },
              typos_lsp = {},
              yamlls = {},
            },
          },
        },
        {
          "mrcjkb/rustaceanvim",
          opts = {
            server = {
              default_settings = {
                ["rust-analyzer"] = {
                  cargo = {
                    allFeatures = true,
                    buildScripts = { enable = true },
                  },
                  check = {
                    command = "clippy",
                    features = "all",
                  },
                  diagnostics = {
                    enable = true,
                    styleLints = { enable = true },
                  },
                  rustc = { source = "discover" },
                },
              },
            },
          },
        },
        {
          "stevearc/conform.nvim",
          opts = {
            formatters_by_ft = {
              bash = { "shfmt" },
              css = { "stylelint" },
              fsharp = { "fantomas" },
              go = { "gofumpt" },
              javascript = { "biome" },
              javascriptreact = { "biome" },
              json = { "jq" },
              lua = { "stylua" },
              nix = { "nixfmt" },
              python = { "isort", "ruff" },
              rust = { "rustfmt" },
              sql = { "sqlfluff" },
              terraform = { "terraform_fmt" },
              typescript = { "biome" },
              typescriptreact = { "biome" },
              yaml = { "yamlfmt" },
            },
          },
        },
      }
    '';

    config = {
      options = ''
        vim.g.mapleader = ","
        vim.g.maplocalleader = ","
      '';

      keymaps = ''
        vim.keymap.set("n", "<leader>[", "<C-w>h", { desc = "Left window" })
        vim.keymap.set("n", "<leader>]", "<C-w>l", { desc = "Right window" })
        vim.keymap.set("n", "<leader>.", "<C-w>j", { desc = "Lower window" })
        vim.keymap.set("n", "<leader>,", "<C-w>k", { desc = "Upper window" })

        vim.keymap.set("n", "|", "<cmd>vsplit<cr>", { desc = "Vertical split" })
        vim.keymap.set("n", "-", "<cmd>split<cr>", { desc = "Horizontal split" })
        vim.keymap.set("n", "Y", "y$", { desc = "Yank to end of line" })
        vim.keymap.set("n", "<C-c>", "<C-^>", { desc = "Toggle between buffers" })

        vim.keymap.set("n", "<M-Up>", "<cmd>move-2<cr>", { desc = "Move line up" })
        vim.keymap.set("n", "<M-Down>", "<cmd>move+<cr>", { desc = "Move line down" })

        vim.keymap.set("v", "K", "<cmd>m '<-2<cr>gv=gv<cr>", { desc = "Move selection up" })
        vim.keymap.set("v", "J", "<cmd>m '>+1<cr>gv=gv<cr>", { desc = "Move selection down" })

        vim.keymap.set("i", "<C-k>", "<C-o>gk")
        vim.keymap.set("i", "<C-h>", "<Left>")
        vim.keymap.set("i", "<C-l>", "<Right>")
        vim.keymap.set("i", "<C-j>", "<C-o>gj")
      '';
    };
  };
}
