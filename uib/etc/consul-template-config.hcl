consul {
  address = "localhost:8500"

  retry {
    enabled = true
    attempts = 0
    backoff = "250ms"
  }
}
template {
  source = "/etc/consul.d/uib.tmpl"
  destination = "/var/run/api.address"
  command = "/usr/sbin/apachectl restart"
}
log_level = "warn"
syslog {
  enabled = true
}
