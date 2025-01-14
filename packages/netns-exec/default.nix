{
  lib,
  rustPlatform,
  inputs,
}:
rustPlatform.buildRustPackage {
  pname = "netns-exec";
  version = inputs.netns-exec.rev;

  useFetchCargoVendor = true;

  src = inputs.netns-exec;
  cargoHash = "sha256-L0IWaoVsI175QkSHD0+aAzA1Lf6RCmEtmzvnR67LhKo=";

  doCheck = false;

  meta = {
    description = "Execute process within Linux network namespace";
    homepage = "https://github.com/johnae/netns-exec";
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
