#!/usr/bin/env sh
set -eu
python3 tools/export_party_catalog.py --check
python3 -m unittest discover -s scripts -p test_continuity_runner.py
GODOT_BIN=${GODOT_BIN:-godot}
case "$("$GODOT_BIN" --version)" in
  4.3.stable.*) ;;
  *) echo "Oathshaper requires Godot 4.3.stable" >&2; exit 2 ;;
esac
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked
cargo run --locked -p oathshaper-core --bin validate_dialogue -- godot/content/lantern_quay.json
cargo run --locked -p oathshaper-core --bin check_continuity -- godot/content/lantern_quay.json godot/content/lantern_quay.continuity.json
cargo run --locked -p oathshaper-core --bin check_dialogue_script -- godot/content/lantern_quay.json godot/content/voice_script.json
cargo run --locked -p oathshaper-core --bin replay_continuity -- godot/content/lantern_quay.json godot/content/lantern_quay.continuity.json godot/content/lantern_quay.journeys.json
./scripts/build-host.sh
"$GODOT_BIN" --headless --path godot --import
"$GODOT_BIN" --headless --path godot --script res://tools/validate_dialogue.gd
"$GODOT_BIN" --headless --path godot --script res://tests/headless_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/rig_slot_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/dialogue_response_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/map_widget_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/garden_mesh_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/records_office_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/route_integration_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/combat_frontend_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/playable_profiles_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/command_trial_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/command_controls_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/combat_pacing_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/camera_hold_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/command_targeting_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/command_ledger_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/command_equipment_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/equipment_mount_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/flow_input_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/flow_trial_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/vanguard_trial_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/chapter_route_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/playtest_continuity_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/player_voice_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/generated_voice_test.gd

"$GODOT_BIN" --headless --path godot --script res://tests/quay_opening_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/garden_confrontation_test.gd
"$GODOT_BIN" --headless --path godot --script res://tests/companion_focus_test.gd

"$GODOT_BIN" --headless --path godot --script res://tests/tower_lighting_test.gd
