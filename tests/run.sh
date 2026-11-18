#!/bin/sh
# Runs the plugin's tests headless. Uses godot from the PATH, or GODOT=/path/to/godot.
# The extension has to be built first, see the README.
set -e
cd "$(dirname "$0")/project"
godot="${GODOT:-godot}"
# maps import again only when they change, not when the plugin does: start from scratch
rm -rf .godot
"$godot" --headless --import >/dev/null 2>&1
exec "$godot" --headless --script res://run_tests.gd
