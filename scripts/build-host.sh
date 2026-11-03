#!/usr/bin/env sh
set -eu
cargo build --locked -p oathshaper-godot
mkdir -p godot/bin
case "$(uname -s)" in
  Darwin) library=liboathshaper_godot.dylib ;;
  Linux) library=liboathshaper_godot.so ;;
  *) echo "Unsupported host" >&2; exit 2 ;;
esac
# Godot may have the previous library mapped in a running editor or demo.
# Replace its directory entry only after the new copy is complete; writing
# through the loaded file can leave macOS reporting an invalid code signature.
staged=$(mktemp "godot/bin/.oathshaper-extension.XXXXXX")
trap 'rm -f "$staged"' EXIT
cp "target/debug/$library" "$staged"
chmod 644 "$staged"
mv -f "$staged" "godot/bin/$library"
trap - EXIT
