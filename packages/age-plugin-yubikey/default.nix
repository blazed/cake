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
  cargoSha256 = "sha256-tq9bfRSuaTPlTuKjSbd3pxWhWMtV+1n4m5f3zTYzeHg=";

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
