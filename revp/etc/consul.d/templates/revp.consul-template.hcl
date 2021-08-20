# Reverse proxy will resolve services' fqdns using the consul-template service.
# When a change in the Consul catalog is detected, the consul-template service rewrites the revp site with this template.

consul {
  address = "localhost:8500"

  retry {
    enabled = true
    attempts = 0
    backoff = "250ms"
  }
}
template {
  source = "/etc/nginx/revp.ctmpl"
  destination = "/etc/nginx/sites-enabled/revp"
  perms = 0600
  command = "service nginx restart"
}
log_level = "warn"
syslog {
  enabled = true
}
