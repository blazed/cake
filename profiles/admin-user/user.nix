{
  adminUser,
  pkgs,
  ...
}: {
  nix.settings.trusted-users = [adminUser.name];
  users = {
    users.${adminUser.name} = {
      inherit (adminUser) uid;
      shell = pkgs.nushell;
      isNormalUser = true;
      hashedPassword = "$6$ai8pClNbaHvh4dHp$DFfY7kC5vIgL8dWPzv24rd60FgmYSSfUu5dbLz623QTeIChQ.hnxoGbJfILKx2jDfqkGGei6ocdF4SUBupyHE/";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7jrwDFcxP329CNp2kUlGH3cvvrY5DHTJdB6ZsjhpnK1yEVpRrG87TOkxrdBOX+s8bVL/8vR3xgvkaKl67zav9JG1xk9HOYKnAHJ7laLX0WJSHsdL9MHblUbVHnn7rXXQvzwmTUacQlF8h8LiTfGAcSNmj9hrehOzkU1v+mpeOsga7yAMuJWI1Tb7AJ+gzHO/72dEeA5VG0JC43KGMW4yYd12pG/58d9RkaT0Et/rXK7zpYhzaPSl1JlCxYYl12OcjQCoWTz5Bq5jS2cW5dup6/N6kuGdanTGxI4yUIWlUyLPjHUZ5g7EcyBuAE2/v33QUFiwhQjNvHdvhoaoil/T1hye2YJfZ6i+ghrN+jW4Prw2znZ+txRhFlIIXmeEMCBN4aLx5oTWH6qXHRGYjCSPhoU+P8jcagBKTApC0gzNK8jH4nJ8VhGs+g+N2337u5pjjCy9IAN9E8wiODgAvsButF+dFkHXEEzJ9pOrin4/MFUpVQklFwVTTCYP2mXa66zkI+JqoTNCkY5uJPxraxKdq0+0aWjh3KApr5vGA6ZFbkHX3tZdOAWTFZkM46Z3ZxohzWJfJg+eLyAmBbRjJjYU6X5lvb697aksAaqjV2NlkEBxmQTFf9QgrrzfTQubP1Nxj1wnrJd/ytofMIiVMVZ5JLAVIatetV9ZICmxF4j6Tiw== cardno:000606444817"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDd9ZjCyGAjtjM6lCVZ46+c3PZvYDzFxECpa3NRwZG8zGnPcbIsFIyQzOdk0eywHFZikNeTxxxiDYXeTnuHuMkweVw5mYIwb8hXj8ts7qoCOVJP9P+KnnEb4WS/edG+Arv1nVeNIXswjHKjOtUSRtoNlRuY0x4kyF9EAbVTrHrB5HDtr7GTGQAGAEp33jQqHrIqFoWmNm9GQ3jqP0b4AcZVRXjAj+amqUQ2+gRt4r1r1kzLuvmOrTbOxnNB/N2hGNCkTbIqP1tDVq03EY0ISOWG+1+TW79ASkSYIdnmQBoB+x6Eh+9CGe65wjM0Op3Q564ZS3Qde1GzMchx5A4W7rrMAOzLXJaQ8Mi7gjsDjrqxBfDDXUU5JL5xn0PhhI1teXvQ5aR90cSs424PS3Yrbqs/pHsybcB/kh25MlO9rGXA9MHh7LlVCPIvus/SDopVgTgNIvhYbQh9xdogkG1XdkvyzXmvAJ6Gk/TR/KRWURwQyp1WJxJ8nHr/zUWrU55zXrN/5gWbDB5k9zuR5G4EGrZshM3EuNeQtjMlHcLWfoZuwaOmar/NOmaXzrBCZb/jXNhQkh6M94krXWE0DIkwsu+5n14llMo/OCxneIEqx4FqZePC8x8qpqfKRzSetOG5PVdCO/8w1erhkg8uETguiPTK4uCfCgtZ75ISpv+7nEwuQ== cardno:000607191648"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICCghZ9Q+hC3hwCS8R6KdqQ8RefZgadLQUYC7upCejNCAAAABHNzaDo="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIH8FItRsdPvpg8mTCF7gsKQJ4ABaOCE8a6PzamumRWe3AAAABHNzaDo="
      ];
      extraGroups = ["wheel" "docker" "video" "audio" "kvm" "libvirtd" "podman"];
    };
  };
}
