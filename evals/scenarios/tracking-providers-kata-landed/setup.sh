# shellcheck shell=bash

setup() {
  # shellcheck disable=SC1091,SC2154
  . "$here/scenarios/tracking-providers-kata/setup.sh"
  setup "$1"
}
