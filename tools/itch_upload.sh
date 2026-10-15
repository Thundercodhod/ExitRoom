#!/bin/sh
# Export the web build and push it to itch.io (https://icekungiir.itch.io/exitroom).
#   sh tools/itch_upload.sh            export + verify + upload
#   sh tools/itch_upload.sh --no-export   upload the existing build/web
# First run asks butler to log in: a browser page opens, press Authorize.
set -eu
cd "$(dirname "$0")/.."
TARGET="icekungiir/exitroom:html5"
GODOT="${GODOT:-/Users/saran/Downloads/Godot.app/Contents/MacOS/Godot}"
BUTLER="$(command -v butler || echo "$HOME/.local/share/butler/butler")"

if [ "${1:-}" != "--no-export" ]; then
	rm -rf build/web && mkdir -p build/web
	"$GODOT" --headless --path . --export-release "Web" build/web/index.html
	# Same check as CI: the packed resources, not the source tree.
	"$GODOT" --headless --main-pack build/web/index.pck --script "$PWD/tools/verify_release.gd" 2>&1 | tee /tmp/exitroom-pack.log
	if grep -qE '^(SCRIPT ERROR|SHADER ERROR|ERROR):' /tmp/exitroom-pack.log; then echo "packed build failed verification"; exit 1; fi
fi

"$BUTLER" login
"$BUTLER" push build/web "$TARGET" --userversion "$(git rev-parse --short HEAD)"
"$BUTLER" status "$TARGET"
