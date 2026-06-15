#!/usr/bin/env bash
# Resolves the xray-vpn (or compatible) container IP at startup and exports
# HTTP(S)_PROXY so the wrapped command's outbound traffic gets routed through
# the container's HTTP-proxy inbound. Used when the host's ISP blocks
# Telegram (or other) traffic but the xray container has a working WARP
# outbound configured.
#
# Prerequisites on the host:
#   1. Docker container named `xray-vpn` running, with an `http` inbound
#      bound to 0.0.0.0:1080 inside the container.
#   2. Xray routing rules forwarding telegram.org / etc. to a warp outbound.
#      (See xray-config snippet in seed-memory/known-quirks.md.)
#
# If xray-vpn isn't running, no proxy is set — the wrapped command attempts
# direct connection (fails loudly, which is what we want).

XRAY_IP="$(docker inspect xray-vpn --format '{{ range .NetworkSettings.Networks }}{{ .IPAddress }}{{ end }}' 2>/dev/null | head -1)"

if [[ -n "$XRAY_IP" ]]; then
  export HTTP_PROXY="http://${XRAY_IP}:1080"
  export HTTPS_PROXY="http://${XRAY_IP}:1080"
  export http_proxy="http://${XRAY_IP}:1080"
  export https_proxy="http://${XRAY_IP}:1080"
  export NO_PROXY="127.0.0.1,localhost,172.17.0.1"
  export no_proxy="127.0.0.1,localhost,172.17.0.1"
fi

exec "$@"
