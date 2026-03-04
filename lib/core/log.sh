#!/usr/bin/env bash

log_info() {
  echo "INFO: $*"
}

log_ok() {
  echo "OK: $*"
}

log_success() {
  log_ok "$@"
}

log_warn() {
  echo "WARN: $*" >&2
}

log_error() {
  echo "ERROR: $*" >&2
}

die() {
  log_error "$*"
  exit 1
}
