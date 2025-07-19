{
  config,
  lib,
  pkgs,
  ...
}: {
  globals = {
    load_ruby_provider = 0;
    load_perl_provider = 0;
    load_python_provider = 0;

    disable_diagnostics = false;
    disable_autoformat = false;
    spell_enabled = true;
    colorizing_enabled = false;
    first_buffer_opened = false;
    whitespace_character_enabled = false;
  };

  clipboard = {
    register = "unnamedplus";

    providers = {
      wl-copy = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        enable = true;
        package = pkgs.wl-clipboard;
      };
    };
  };

  opts = {
    completeopt = lib.mkIf (!config.plugins.blink-cmp.enable) [
      "fuzzy"
      "menuone"
      "noselect"
      "popup"
    ];

    updatetime = 100;

    number = true;
    relativenumber = true;
    mouse = "a";
    mousemodel = "extend";
    splitbelow = true;
    splitright = true;

    swapfile = false;
    modeline = true;
    modelines = true;
    undofile = true;
    incsearch = true;
    ignorecase = true;

    smartcase = true;
    cursorline = true;
    cursorcolumn = false;
    signcolumn = "yes";
    colorcolumn = "100";
    laststatus = 3;
    fileencoding = "utf-8";
    termguicolors = true;
    spelllang = lib.mkDefault ["en_us"];
    spell = true;
    wrap = false;

    tabstop = 2;
    shiftwidth = 2;
    softtabstop = 0;
    expandtab = true;
    autoindent = true;

    textwidth = 0;

    # Folding
    foldlevel = 99; # Folds with a level higher than this number will be closed
    foldcolumn = "1";
    foldenable = true;
    foldlevelstart = -1;
    fillchars = {
      horiz = "━";
      horizup = "┻";
      horizdown = "┳";
      vert = "┃";
      vertleft = "┫";
      vertright = "┣";
      verthoriz = "╋";

      eob = " ";
      diff = "╱";

      fold = " ";
      foldopen = "";
      foldclose = "";

      msgsep = "‾";

      breakindent = true;
      cmdheight = 0;
      copyindent = true;

      history = 1000;
      infercase = true;
      linebreak = true;
      preserveindent = true;
      pumheight = 10;
      showmode = false;
      showtabline = 2;
      timeoutlen = 500;
      title = true;
      virtualedit = "block";
      writebackup = false;

      lazyredraw = false;
      synmaxcol = 240;
      showmatch = true;
      matchtime = 1;
      startofline = true;
      report = 9001;
    };
  };
}
