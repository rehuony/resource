#!/usr/bin/env bash

# shellscript.lib.sh
# Author: rehuony
# Description: Template file used to create library shellscript
# GitHub: https://github.com/rehuony/resource

# Enable the following shell options:
# -E: Ensure that ERR trap is also valid in function, subshell, and command replacements
# -e: When any command exits in a non-zero state, exit the script immediately
# -u: When using undefined variables, the script will report an error and exit
# -o pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

lib_command_dependency=() # CONFIG: commands appearing in library script
lib_package_dependency=() # CONFIG: corresponding package name of the command

# -------------------------------------------------------------------
# function_name
#
# Description:
#   Description for function
#
# Arguments:
#   $1 - argument 1 (e.g. "demo1")
#   $2 - argument 2 (e.g. "demo2")
#
# Returns:
#   0 - success
#   1 - error
#
# Usage:
#   function_name "demo1" "demo2"
# -------------------------------------------------------------------
# function_name() {
#   return 0
# }
