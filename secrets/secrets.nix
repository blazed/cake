let
  inherit (builtins) any all replaceStrings filter foldl' elem listToAttrs
    attrValues concatMap isList mapAttrs fromTOML readFile hasAttr getFlake;

  flatten = x: if isList x
               then concatMap flatten x
               else [x];

  unique = foldl' (acc: e: if elem e acc then acc else acc ++ [ e ]) [];

  hasAttrsFilter = attrsList: filter (attr: all (key: hasAttr key attr) attrsList);

  hostConfigsList = attrValues (getFlake (toString ../.)).hostConfigs;

  hostsWithSecrets = hasAttrsFilter [ "publicKey" "age" ] hostConfigsList;

  toLocalSecretPath = replaceStrings [ "secrets/" ] [ "" ];

  secretsList = unique (flatten (map (host: map (s: toLocalSecretPath s.file) (attrValues host.age.secrets)) hostsWithSecrets));

  mapSecretToPublicKeys = secret:
    map (host: host.publicKey)
      (filter (host: any (s: secret == toLocalSecretPath s.file) (attrValues host.age.secrets)) hostsWithSecrets);

  blazed = [
    "age1yubikey1q0k3xmsmjjh5mduf7r588s9g4hhz66ervpgwr9aejcxyxdrea0gg6972h4y"
  ];

in

listToAttrs (map (name: {
  inherit name;
  value.publicKeys = blazed ++ (mapSecretToPublicKeys name);
}) secretsList)
