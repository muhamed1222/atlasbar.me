#!/usr/bin/env bash

run_xcodebuild() {
  local filtered_message="IDERunDestination: Supported platforms for the buildables in the current scheme is empty."

  xcodebuild "$@" 2> >(grep -Fv "$filtered_message" >&2)
}
