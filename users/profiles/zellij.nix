{
  pkgs,
  config,
  lib,
  ...
}: {
  xdg.configFile."zellij/config.kdl".text = ''
    keybinds clear-defaults=true {
      locked {
        bind "Ctrl g" { SwitchToMode "Normal"; }
      }

      shared_except "normal" "locked" "search" "scroll" {
        bind "Enter" "Esc" { SwitchToMode "Normal"; }
      }

      shared_among "search" "scroll" {
        bind "Esc" { ScrollToBottom; SwitchToMode "Normal"; }
      }

      shared_except "locked" "pane" {
        bind "Ctrl p" { SwitchToMode "Pane"; }
      }

      shared_except "locked" "resize" {
        bind "Ctrl r" { SwitchToMode "Resize"; }
      }

      shared_except "entersearch" "resize" {
        bind "Ctrl f" { SwitchToMode "EnterSearch"; SearchInput 0; }
      }

      shared_except "locked" "move" {
        bind "Ctrl m" { SwitchToMode "Move"; }
      }

      shared_except "locked" "scroll" {
        bind "Ctrl s" { SwitchToMode "Scroll"; }
      }

      shared_except "locked" "tab" {
        bind "Ctrl t" { SwitchToMode "Tab"; }
      }

      shared_except "locked" {
        bind "Ctrl w" { FocusNextPane; }
        bind "Ctrl n" { NewPane "Right"; SwitchToMode "Normal"; }
        bind "Ctrl h" { NewPane "Down"; SwitchToMode "Normal"; }
        bind "Ctrl z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
        bind "Ctrl o" { ToggleFloatingPanes; }
        bind "Ctrl g" { SwitchToMode "Locked"; }
        bind "Ctrl d" { Detach; }
        bind "Ctrl q" { Quit; }
      }

      pane {
        bind "h" "Left" { MoveFocusOrTab "Left"; }
        bind "l" "Right" { MoveFocusOrTab "Right"; }
        bind "j" "Down" { MoveFocusOrTab "Down"; }
        bind "k" "Up" { MoveFocusOrTab "Up"; }
        bind "-" { NewPane "Down"; SwitchToMode "Normal"; }
        bind "|" { NewPane "Right"; SwitchToMode "Normal"; }
        bind "{" { MovePane "Down"; }
        bind "}" { MovePane "Up"; }
        bind "+" { MovePane "Right"; }
        bind "&" { MovePane "Left"; }
        bind "g" { SwitchFocus; }
        bind "x" { CloseFocus; SwitchToMode "Normal"; }
        bind "z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
        bind "f" { TogglePaneFrames; SwitchToMode "Normal"; }
      }

      move {
        bind "Tab" { MovePane; }
        bind "l" "Right" { MovePane "Right"; }
        bind "h" "Left" { MovePane "Left"; }
        bind "k" "Up" { MovePane "Up"; }
        bind "j" "Down" { MovePane "Down"; }
      }

      tab {
        bind "Tab" { ToggleTab; }
        bind "l" "Right" { GoToNextTab; }
        bind "h" "Left" { GoToPreviousTab; }
        bind "n" { NewTab; SwitchToMode "Normal"; }
        bind "x" { CloseTab; SwitchToMode "Normal"; }
      }
    }

    plugins {
      tab-bar { path "tab-bar"; }
      status-bar { path "status-bar"; }
      strider { path "strider"; }
      compact-bar { path "compact-bar"; }
      session-manager { path "session-manager"; }
    }

    theme "nord"

    copy_command "wl-copy"
  '';

  programs.zellij = {
    enable = true;
  };
}
