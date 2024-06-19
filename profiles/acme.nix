{
  security.acme.acceptTerms = true;
  security.acme.defaults = {
    email = "certs@exsules.com";
    dnsResolver = "1.1.1.1:53";
    dnsProvider = "cloudflare";
    credentialsFile = "/run/agenix/acme-cloudflare";
  };
}
