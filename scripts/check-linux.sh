#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."
mkdir -p godot/bin
archive=godot/bin/Godot_v4.3-stable_linux.x86_64.zip
engine=godot/bin/Godot_v4.3-stable_linux.x86_64
expected=7de56444b130b10af84d19c7e0cf63cf9e9937ee4ba94364c3b7dd114253ca21
if [ ! -f "$archive" ]; then
  curl -fL "https://github.com/godotengine/godot-builds/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip" -o "$archive"
fi
if command -v shasum >/dev/null 2>&1; then
  actual=$(LC_ALL=C shasum -a 256 "$archive" | cut -d ' ' -f 1)
else
  actual=$(sha256sum "$archive" | cut -d ' ' -f 1)
fi
if [ "$actual" != "$expected" ]; then
  echo "Godot Linux archive hash mismatch" >&2
  exit 2
fi
if [ ! -f "$engine" ]; then
  unzip -q "$archive" -d godot/bin
fi
chmod +x "$engine"

docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 cargo build --locked --release -p oathshaper-godot
cp target/release/liboathshaper_godot.so godot/bin/
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --import
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tools/validate_dialogue.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/headless_test.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/rig_slot_test.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/dialogue_response_test.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/map_widget_test.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/garden_mesh_test.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/records_office_test.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/route_integration_test.gd
docker run --rm --platform linux/amd64 -v "$PWD:/work" -w /work rust:1.95.0 /work/godot/bin/Godot_v4.3-stable_linux.x86_64 --headless --path godot --script res://tests/combat_pacing_test.gd
