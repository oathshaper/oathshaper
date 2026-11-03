# Install the Lantern Quay demo

Download a native archive and its `.sha256` file from [Releases](https://github.com/oathshaper/oathshaper/releases). Use the release's platform test notes to distinguish automated acceptance from physical-device playtesting. Extract the complete archive before launching; retain `licenses/` beside the game.

## macOS

Open `Oathshaper.app` from the extracted folder. The universal binary includes Apple Silicon and Intel code. It is ad-hoc signed, not notarized. For a download you trust, macOS offers **Open Anyway** in **System Settings → Privacy & Security** after a blocked launch. No system-wide security setting needs to be disabled.

## Windows

Extract the ZIP, then run `Oathshaper.exe`. Keep the DLL and other extracted files beside it. The executable is unsigned, so Windows may show a publisher warning. No developer tools or separate Rust runtime are required.

## Linux

Extract the tarball and launch `./Oathshaper.x86_64`. Executable permissions are retained by the tar archive. The build targets Linux x86_64 with an Ubuntu 22.04-compatible runtime and a working graphics driver.

## Steam Deck

In Desktop Mode, extract the Linux tarball, add `Oathshaper.x86_64` to Steam as a non-Steam game, and set its **Start In** folder to the extracted game directory. Try native Linux first. Return to Gaming Mode to launch it. This is a testing path; the demo is not Steam Deck Verified and physical Deck acceptance remains separate from CI.

## Start playing

Choose **The Quay Robbery** for the story, or **Combat styles** to inspect all nine designs. Command, Flow and Vanguard are playable; styles 04–09 are previews. Command is the recommended first run.

| Context | Keyboard / mouse |
| --- | --- |
| Explore | WASD move, right drag camera, E interact, Tab journal |
| Dialogue | Up/Down select, Enter confirm, Esc leave or skip |
| Command | Space pause/resume, Tab party, T target, I party sheet |
| Flow | WASD move, 1–4 styles, left/right click attacks, Shift guard, Space dodge |
| Vanguard | Mouse aim, left click fire, WASD move; use the displayed cover and squad prompts |

Hints change with the most recent keyboard/mouse/controller input. Physical controllers have not been certified by automated keyboard tests. Music and voices are included; no model downloads or online account are needed.

## Checksums and bug reports

Compare the archive's SHA-256 with its companion file (`shasum -a 256`, `sha256sum`, or PowerShell `Get-FileHash -Algorithm SHA256`). `BUILD-MANIFEST.json` records the source revision and file hashes.

For a bug report, include your OS, CPU/GPU, combat style, reproduction steps and the archive's revision. Review logs for personal paths before posting. Earlier incompatible story saves are rejected without being overwritten; use a new journey for the current story.
