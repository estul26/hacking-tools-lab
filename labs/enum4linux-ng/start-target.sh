#!/usr/bin/env sh
set -eu

mkdir -p /run/samba

exec smbd --foreground --no-process-group
