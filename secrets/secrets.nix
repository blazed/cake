let
  inherit (builtins)
    all
    any
    attrValues
    concatMap
    elem
    elemAt
    filter
    foldl'
    getFlake
    hasAttr
    isList
    length
    listToAttrs
    split
    ;

  last = list: elemAt list (length list - 1);

  flatten = x: if isList x then concatMap flatten x else [ x ];

  unique = foldl' (acc: e: if elem e acc then acc else acc ++ [ e ]) [ ];

  hasAttrsFilter = attrsList: filter (attr: all (key: hasAttr key attr) attrsList);

  hostConfigsList = map (host: host.config) (
    attrValues (getFlake (toString ../.)).nixosConfigurations
  );

  hostsWithSecrets = hasAttrsFilter [ "publicKey" "age" ] hostConfigsList;

  toLocalSecretPath = path: last (split "/secrets/" path);

  secretsList = unique (
    flatten (
      map (
        host: map (s: toLocalSecretPath (toString s.file)) (attrValues host.age.secrets)
      ) hostsWithSecrets
    )
  );

  mapSecretToPublicKeys =
    secret:
    unique (
      map (host: host.publicKey) (
        filter (
          host: any (s: secret == toLocalSecretPath (toString s.file)) (attrValues host.age.secrets)
        ) hostsWithSecrets
      )
    );

  blazed = [
    "age1yubikey1q0k3xmsmjjh5mduf7r588s9g4hhz66ervpgwr9aejcxyxdrea0gg6972h4y"
    "age1yubikey1q2k0cy4anjwggg5spvjrglyy7jgjclnmjddja460yhaqm6wcc5dhjmuxcqh"
  ];
in
listToAttrs (
  map (name: {
    inherit name;
    value.publicKeys = blazed ++ (mapSecretToPublicKeys name);
  }) secretsList
)
