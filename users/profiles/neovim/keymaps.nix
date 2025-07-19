{
  helpers,
  lib,
  ...
}: {
  globals = {
    mapleader = ",";
    maplocalleader = ",";
  };

  keymaps = let
    normal =
      lib.mapAttrsToList
      (
        key: {action, ...} @ attrs: {
          mode = "n";
          inherit action key;
          options = attrs.options or {};
        }
      )
      {
        "<esc>" = {
          action = "<cmd>noh<CR>";
        };
      };
    visual =
      lib.mapAttrsToList
      (
        key: {action, ...} @ attrs: {
          mode = "v";
          inherit action key;
          options = attrs.options or {};
        }
      )
      {
        # Better indenting
        "<S-Tab>" = {
          action = "<gv";
          options = {
            desc = "Unindent line";
          };
        };
      };
    insert =
      lib.mapAttrsToList
      (
        key: {action, ...} @ attrs: {
          mode = "i";
          inherit action key;
          options = attrs.options or {};
        }
      )
      {
        # Move selected line/block in insert mode
        "<C-k>" = {
          action = "<C-o>gk";
        };
        "<C-h>" = {
          action = "<Left>";
        };
        "<C-l>" = {
          action = "<Right>";
        };
        "<C-j>" = {
          action = "<C-o>gj";
        };
      };
  in
    helpers.keymaps.mkKeymaps {options.silent = true;} (normal ++ visual ++ insert);

  plugins.which-key.settings.spec = [
    {
      __unkeyed-1 = "<leader>w";
      icon = "";
    }
    {
      __unkeyed-1 = "<leader>W";
      icon = "󰽃";
    }
    {
      __unkeyed-1 = "<leader>/";
      icon = "";
    }
    {
      __unkeyed-1 = "<leader>a";
      group = "AI Assistant";
      icon = "";
    }
  ];
}
