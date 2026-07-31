{ pkgs, piNode }:
let
  piPackageDir = "${piNode}/lib/node_modules/@earendil-works/pi-coding-agent";
  subagentsCheck = pkgs.callPackage ./subagents-package.nix { inherit piNode; };
  localCheck =
    pkgs.runCommand "pi-local-extensions-check"
      {
        nativeBuildInputs = [
          pkgs.jujutsu
          pkgs.nodejs
          pkgs.typescript
        ];
      }
      ''
        work="$TMPDIR/pi-local-extensions"
        mkdir -p "$work"/node_modules/@earendil-works
        cp -r ${./extensions} "$work/extensions"
        cp -r ${./extension-tests} "$work/extension-tests"
        chmod -R u+w "$work"
        rm -rf "$work/extensions/subagents"

        test -d ${piPackageDir}/node_modules/@earendil-works/pi-agent-core
        test -d ${piPackageDir}/node_modules/@earendil-works/pi-ai
        test -d ${piPackageDir}/node_modules/@earendil-works/pi-tui
        test -d ${piPackageDir}/node_modules/@types/node
        test -d ${piPackageDir}/node_modules/typebox
        ln -s ${piPackageDir} "$work/node_modules/@earendil-works/pi-coding-agent"
        for package in pi-agent-core pi-ai pi-tui; do
          ln -s ${piPackageDir}/node_modules/@earendil-works/$package \
            "$work/node_modules/@earendil-works/$package"
        done
        mkdir -p "$work/node_modules/@types"
        ln -s ${piPackageDir}/node_modules/@types/node "$work/node_modules/@types/node"
        ln -s ${piPackageDir}/node_modules/typebox "$work/node_modules/typebox"

        cat > "$work/package.json" <<'EOF'
        { "private": true, "type": "module" }
        EOF
        cat > "$work/tsconfig.json" <<'EOF'
        {
          "compilerOptions": {
            "allowImportingTsExtensions": true,
            "module": "NodeNext",
            "moduleResolution": "NodeNext",
            "noEmit": true,
            "skipLibCheck": true,
            "strict": true,
            "target": "ES2022",
            "types": ["node"]
          },
          "include": ["extensions/**/*.ts", "extension-tests/**/*.ts"]
        }
        EOF

        cd "$work"
        tsc --noEmit -p .
        node --test --experimental-strip-types

        mkdir -p "$out"
        echo "local Pi extension typecheck and tests passed" > "$out/result"
      '';
in
pkgs.runCommand "pi-extensions-check" { } ''
  test -e ${localCheck}/result
  test -e ${subagentsCheck}/index.ts
  mkdir -p "$out"
  echo "all local Pi extension checks passed" > "$out/result"
''
