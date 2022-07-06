#!/usr/bin/env bash

function ensure_command_line_tools() {
    echo "Installing Command Line Tools"
    local LOCKF="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$LOCKF";
    # shellcheck disable=SC2064
    trap "rm $LOCKF" RETURN
    PROD=$(softwareupdate -l |
      grep "\*.*Command Line" |
      head -n 1 |
      grep -oE "Command.*" |
      tr -d '\n')
    softwareupdate -i "$PROD" --verbose
}

ensure_command_line_tools
