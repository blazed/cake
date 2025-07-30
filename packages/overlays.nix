{
  inputs,
  lib,
  ...
}:
let
  inherit (lib) genAttrs;
  inherit (builtins) filter pathExists attrNames;

  pkgList = filter (
    elem: !(inputs.${elem} ? "sourceInfo") && pathExists (toString (./. + "/${elem}"))
  ) (attrNames inputs);
in
(genAttrs pkgList (
  key: (final: prev: { ${key} = prev.callPackage (./. + "/${key}") { inherit inputs; }; })
))
// {
  inputs = final: prev: { inherit inputs; };
}
