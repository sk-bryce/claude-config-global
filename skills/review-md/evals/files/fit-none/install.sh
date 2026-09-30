#!/bin/sh
# install.sh - install a notectl binary and its default config on this host.
# Usage: sudo ./install.sh <path-to-notectl-binary>
set -eu

if [ $# -ne 1 ]; then
  echo "usage: install.sh <path-to-notectl-binary>" >&2
  exit 2
fi

install -m 0755 "$1" /usr/local/bin/notectl
mkdir -p /etc/notectl
if [ ! -f /etc/notectl/notectl.toml ]; then
  install -m 0644 config/notectl.toml /etc/notectl/notectl.toml
fi
echo "notectl installed to /usr/local/bin/notectl"
