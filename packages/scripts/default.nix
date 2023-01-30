{
  writeShellApplication,
  wpa_supplicant,
  stdenv,
  hostname,
  buildEnv,
  lib,
}: let
  tm = writeShellApplication {
    name = "tm";
    text = ''
      #!${stdenv.shell}
      [ "$TMUX" == "" ] || exit 0

      PS3="Please choose your session: "
      options=($(tmux list-sessions -F "#S" 2>/dev/null) "New Session" "fish")
      echo "Available sessions"
      echo "------------------"
      echo " "
      select opt in "''${options[@]}"
      do
          case $opt in
              "New Session")
                  read -rp "Enter new session name: " SESSION_NAME
                  tmux new -s "$SESSION_NAME"
                  break
                  ;;
              "fish")
                  fish --login
                  break;;
              *)
                  tmux attach-session -t "$opt"
                  break
                  ;;
          esac
      done
    '';
  };

  compress = writeShellApplication {
    name = "compress";
    text = ''
      tar -cjf "$1_$(date +"%Y%m%d")".tar.bz2 "$2"
    '';
  };
in
  buildEnv {
    name = "scripts";
    paths = [
      compress
      tm
    ];
  }
