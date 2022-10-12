{
  lib,
  rustPlatform,
  pkg-config,
  pcsclite,
  inputs,
}:
rustPlatform.buildRustPackage {
  pname = "age-plugin-yubikey";
  version = inputs.age-plugin-yubikey.rev;

  src = inputs.age-plugin-yubikey;
  cargoSha256 = "sha256-6J+xogL5t/FxStUz/hPrifhoGM95hyfTwJGntxRZ4U4=";

  nativeBuildInputs = [pkg-config];
  buildInputs = [pcsclite];

  doCheck = false;

  meta = {
    license = lib.licenses.mit;
    maintainers = [
      {
        email = "john@insane.se";
        github = "johnae";
        name = "John Axel Eriksson";
      }
    ];
  };
}
