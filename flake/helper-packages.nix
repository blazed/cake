{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs)
        stdenv
        lib
        writeShellApplication
        buildEnv
        fire
        hostname
        pass
        wpa_supplicant
        ;

      launch = writeShellApplication {
        name = "launch";
        runtimeInputs = [ fire ];
        text = ''
          cmd=$*
          if [ -z "$cmd" ]; then
            read -r cmd
          fi
          echo "fire $cmd" | ${stdenv.shell}
        '';
      };

      update-wireguard-keys = writeShellApplication {
        name = "update-wireguard-keys";
        runtimeInputs = [
          hostname
          pass
        ];
        text = ''
          IFS=$'\n'
          HN="$(hostname)"
          for KEY in $(find "$PASSWORD_STORE_DIR"/vpn/wireguard/"$HN"/ -type f -print0 | xargs -0 -I{} basename {}); do
            KEYNAME=$(basename "$KEY" .gpg)
            echo "Ensure wireguard key \"$KEYNAME\" is available"
            pass show "vpn/wireguard/$HN/$KEYNAME" | sudo tee /var/lib/wireguard/"$KEYNAME" > /dev/null
            sudo chmod 0600 /var/lib/wireguard/"$KEYNAME"
          done
        '';
      };

      update-wifi-networks = writeShellApplication {
        name = "update-wifi-networks";
        runtimeInputs = [ pass ];
        text = ''
          IFS=$'\n'
          for NET in $(find "$PASSWORD_STORE_DIR"/wifi/networks/ -type f -print0 | xargs -0 -I{} basename {}); do
            NETNAME=$(basename "$NET" .gpg)
            echo "Ensure wireless network \"$NETNAME\" is available"
            pass show "wifi/networks/$NETNAME" | sudo tee "/var/lib/iwd/$NETNAME.psk" > /dev/null
          done
        '';
      };

      add-wifi-network = writeShellApplication {
        name = "add-wifi-network";
        runtimeInputs = [
          wpa_supplicant
          pass
          update-wifi-networks
        ];
        text = ''
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
          PSK=$(wpa_passphrase "$1" "$2" | grep "[^#]psk=" | awk -F'=' '{print $2}')
          if [ -z "$PSK" ]; then
            echo Hmm PSK was empty
            exit 1
          fi
          cat <<EOF | pass insert -m "wifi/networks/$NET"
          [Security]
          PreSharedKey=$PSK
          Passphrase=$PASS
          EOF
          update-wifi-networks
        '';
      };
    in
    {
      packages = {
        scripts = buildEnv {
          name = "scripts";
          paths = [
            add-wifi-network
            launch
            update-wifi-networks
            update-wireguard-keys
          ];
          meta.platforms = lib.platforms.linux;
        };
      };
    };
}
