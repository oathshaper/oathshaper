# M1 evidence ledger

Verified 2026-10-19. The project pins Godot `4.3.stable` in `.godot-version`, `godot-rust =0.2.4` with `api-4-3` in Cargo, and Rust `1.95.0` in `rust-toolchain.toml`.

This is a historical M1 record. Its Start/Select save and load bindings predate the records route; the [current controls](../README.md#play-lantern-quay) use Start/Menu for the journal and Back/View for the map.

| Surface | Command or method | Result |
| --- | --- | --- |
| Rust host checks | `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot sh scripts/check.sh` on macOS arm64 | Exit 0. Format and Clippy clean; 12 narrative tests passed; story CLI validation passed; macOS extension built and loaded. |
| Godot host scene | Same script, including headless story and scene checks | Exit 0. Simulated controller left stick, A, D-pad, B, Start, and Select; validated changed line, lamp consequence, missing voice, active-dialogue save/load, and exploration reload. |
| Desktop launch | `/Applications/Godot.app/Contents/MacOS/Godot --path godot --quit-after 30` | Exit 0 under OpenGL Compatibility on Apple M4 Pro. A 1280×800 graphical dialogue capture is in `docs/images/lantern-quay-dialogue.png`. |
| Linux x86-64 extension | `sh scripts/check-linux.sh` using Docker `linux/amd64` and Rust 1.95.0 | Exit 0. Produced ELF x86-64 `target/release/liboathshaper_godot.so`, SHA-256 `82ee978e7cb7251ed6a7dc73bf34a1be33e04d4aa1fa568edfc4168420609c54`. The Docker server itself was `linux/arm64`, so this was emulated x86-64. |
| Linux Godot runtime | Same script, official Godot 4.3.stable Linux x86-64 binary with archive SHA-256 `7de56444b130b10af84d19c7e0cf63cf9e9937ee4ba94364c3b7dd114253ca21` | Both headless story validation and full scene test exited 0; extension initialized against API and runtime `v4.3.stable.official`. |
| Physical controller and Steam Deck | No physical device session | Not tested. Controller evidence is synthetic Godot input events, and Linux evidence is a container check rather than a Steam Deck launch or performance run. |

Both macOS and Linux headless scene runs printed six Godot dummy-renderer `mesh_get_surface_count: Parameter "m" is null` errors after the passing marker. The graphical macOS run did not print these errors. The headless checks still exited 0; a native Linux graphical run and Steam Deck hardware run remain to be done.

reference prototype remained untouched: its HEAD was `778159cee98bb07a3e7dd70e8f01b9190a18bbaf` and `git status --porcelain` was empty after the audit and implementation.
