{
  programs.tmux = {
    enable = true;
    historyLimit = 20000;
    keyMode = "vi";
    shortcut = "a";
    terminal = "screen-256color";
    escapeTime = 0;
    extraConfig = ''
      set -g renumber-windows on
      setw -g aggressive-resize on
      setw -g mouse on
      bind N new-window
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind -r C-h select-window -t :-
      bind -r C-l select-window -t :+
      bind y setw synchronize-panes
      unbind [
      bind Escape copy-mode
      unbind p
      bind p paste-buffer
      bind-key -Tcopy-mode-vi 'v' send -X begin-selection
      bind-key -Tcopy-mode-vi 'y' send -X copy-selection
      bind-key -Tcopy-mode-vi 'Y' send -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
    '';
  };
}
