{
  config,
  lib,
  ...
}: {
  imports = [
    # keep-sorted start
    ./lsp/lspconfig.nix
    # keep-sorted end
  ];

  lsp = {
    inlayHints.enable = true;

    servers = {
      "*" = {
        capabilities = {
          textDocument = {
            semanticTokens = {
              multilineTokenSupport = true;
            };
          };
        };
        root_markers = [
          ".git"
        ];
      };

      cssls.enable = true;
      dockerls.enable = true;
      fsautocomplete.enable = true;
      gopls.enable = true;
      html.enable = true;
      jsonls.enable = true;
      lua_ls.enable = true;
      markman.enable = true;
      nushell.enable = true;
      sqls.enable = true;
      statix.enable = true;
      yamlls.enable = true;
    };

    keymapsOnEvents.LspAttach =
      [
        (lib.mkIf (!config.plugins.conform-nvim.enable) {
          action.__raw = ''vim.lsp.buf.format'';
          mode = "v";
          key = "<leader>lf";
          options = {
            silent = true;
            buffer = false;
            desc = "Format selection";
          };
        })
        # Diagnostic keymaps
        {
          key = "<leader>lH";
          mode = "n";
          action = lib.nixvim.mkRaw "vim.diagnostic.open_float";
          options = {
            silent = true;
            desc = "Lsp diagnostic open_float";
          };
        }
      ]
      ++ lib.optionals (!config.plugins.glance.enable) [
        {
          action = "<CMD>PeekDefinition textDocument/definition<CR>";
          mode = "n";
          key = "<leader>lp";
          options = {
            desc = "Preview definition";
          };
        }
        {
          action = "<CMD>PeekDefinition textDocument/typeDefinition<CR>";
          mode = "n";
          key = "<leader>lP";
          options = {
            desc = "Preview type definition";
          };
        }
      ]
      ++ lib.optionals (!config.plugins.conform-nvim.enable) [
        # Format keymap (if conform-nvim is not enabled)
        {
          key = "<leader>lf";
          mode = "n";
          action = lib.nixvim.mkRaw "vim.lsp.buf.format";
          options = {
            silent = true;
            desc = "Lsp buf format";
          };
        }
      ]
      ++ lib.optionals
      (
        !config.plugins.fzf-lua.enable
        || (config.plugins.snacks.enable && lib.hasAttr "picker" config.plugins.snacks.settings)
      )
      [
        # Code action keymap (if fzf-lua is not enabled)
        {
          key = "<leader>la";
          mode = "n";
          action = lib.nixvim.mkRaw "vim.lsp.buf.code_action";
          options = {
            silent = true;
            desc = "Lsp buf code_action";
          };
        }
      ]
      ++ lib.optionals
      (
        (
          !config.plugins.snacks.enable
          || (config.plugins.snacks.enable && !lib.hasAttr "picker" config.plugins.snacks.settings)
        )
        && !config.plugins.fzf-lua.enable
      )
      [
        # Definition and type_definition keymaps (conditionally)
        {
          key = "<leader>ld";
          mode = "n";
          action = lib.nixvim.mkRaw "vim.lsp.buf.definition";
          options = {
            silent = true;
            desc = "Lsp buf definition";
          };
        }
        {
          key = "<leader>lt";
          mode = "n";
          action = lib.nixvim.mkRaw "vim.lsp.buf.type_definition";
          options = {
            silent = true;
            desc = "Lsp buf type_definition";
          };
        }
      ];
  };
  plugins = {
    lsp-format.enable = !config.plugins.conform-nvim.enable && config.plugins.lsp.enable;
    lsp-signature.enable = config.plugins.lsp.enable;

    which-key.settings.spec = [
      {
        __unkeyed-1 = "<leader>l";
        group = "LSP";
        icon = " ";
      }
      {
        __unkeyed-1 = "<leader>l[";
        desc = "Prev";
      }
      {
        __unkeyed-1 = "<leader>l]";
        desc = "Next";
      }
      {
        __unkeyed-1 = "<leader>a";
        desc = "Code Action";
      }
      {
        __unkeyed-1 = "<leader>ld";
        desc = "Definition";
      }
      {
        __unkeyed-1 = "<leader>lD";
        desc = "References";
      }
      {
        __unkeyed-1 = "<leader>lf";
        desc = "Format";
      }
      {
        __unkeyed-1 = "<leader>lh";
        desc = "Lsp Hover";
      }
      {
        __unkeyed-1 = "<leader>lH";
        desc = "Diagnostic Hover";
      }
      {
        __unkeyed-1 = "<leader>li";
        desc = "Implementation";
      }
      {
        __unkeyed-1 = "<leader>lr";
        desc = "Rename";
      }
      {
        __unkeyed-1 = "<leader>lt";
        desc = "Type Definition";
      }
    ];
  };
}
