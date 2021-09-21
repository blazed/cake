{ 
  writeScriptBin,
  writeStrictShellScriptBin,
  gopass,
  wpa_supplicant,
  stdenv,
  hostname,
  buildEnv,
  lib,
}:
let

  addToBinPath = pkgs: ''
    export PATH=${lib.makeBinPath pkgs}''${PATH:+:''${PATH}}
  '';

  tm = writeScriptBin "tm" ''
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

  compress = writeStrictShellScriptBin "compress" ''
    tar -cjf "$1_$(date +"%Y%m%d")".tar.bz2 "$2"
  '';

  update-wifi-networks = writeStrictShellScriptBin "update-wifi-networks" ''
    ${addToBinPath [ gopass ]}
    IFS=$'\n'
    for NET in $(find /home/blazed/code/blazed/gopass-store/wifi/networks/ -type f -print0 | xargs -0 -I{} basename {}); do
      NETNAME=$(basename "$NET" .gpg)
      echo "Ensure wireless network \"$NETNAME\" is available"
      ${gopass}/bin/gopass show "wifi/networks/$NETNAME" | sudo tee "/var/lib/iwd/$NETNAME.psk" > /dev/null
    done
  '';

  add-wifi-network = writeStrictShellScriptBin "add-wifi-network" ''
    ${addToBinPath [ gopass ]}
    NET=''${1:-}
    PASS=''${2:-}
    if [ -z "$NET" ]; then
      echo Please provide the network as first argument
      exit 1
    fi
    if [ -z "$PASS" ]; then
      echo Please provide the password as second argument
      exit 1
    fi
    PSK=$(${wpa_supplicant}/bin/wpa_passphrase "$1" "$2" | grep "[^#]psk=" | awk -F'=' '{print $2}')
    if [ -z "$PSK" ]; then
      echo PSK was empty
      exit 1
    fi
    cat <<EOF | ${gopass}/bin/gopass insert -m "wifi/networks/$NET"
    [Security]
    PreSharedKey=$PSK
    Passphrase=$PASS
    EOF
    ${update-wifi-networks}/bin/update-wifi-networks
  '';

  update-wireguard-keys = writeStrictShellScriptBin "update-wireguard-keys" ''
    ${addToBinPath [ hostname gopass ]}
    IFS=$'\n'
    HN="$(hostname)"
    for KEY in $(find "$PASSWORD_STORE_DIR"/vpn/wireguard/"$HN"/ -type f -print0 | xargs -0 -I{} basename {}); do
      KEYNAME=$(basename "$KEY" .gpg)
      echo "Ensure wireguard key \"$KEYNAME\" is available"
      gopass show "vpn/wireguard/$HN/$KEYNAME" | sudo tee /var/lib/wireguard/"$KEYNAME" > /dev/null
      sudo chmod 0600 /var/lib/wireguard/"$KEYNAME"
    done
  '';
in
buildEnv {
  name = "scripts";
  paths = [
    add-wifi-network update-wifi-networks
    update-wireguard-keys compress tm
  ];
}
