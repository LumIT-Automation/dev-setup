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

# This is the quiescence timers; it defines the minimum and maximum amount of
# time to wait for the cluster to reach a consistent state before rendering a
# template. This is useful to enable in systems that have a lot of flapping,
# because it will reduce the the number of times a template is rendered.
wait {
  min = "5s"
  max = "10s"
}
