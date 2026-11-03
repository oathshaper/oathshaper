# Combat design branch review index

Completed design milestone: 2026-10-22. All nine profile packets passed independent design review after documented repairs. Their 173 proposed acceptance cases cover timing, equipment, progression, abilities, party, UI, persistence and failure. Human design acceptance and runtime implementation remain separate. No profile has been merged into the runtime.

## Checkpoints

- Existing user work committed on main: `e0c5006`.
- Reviewed minimal foundation: `57b252d82d3b5905bb6a27a90e91c9da952d901d`, retained as `design/combat-lcd`.
- Every profile branches directly from that frozen foundation. Profile work is restricted to its own `docs/combat-design/profiles/<id>/` directory.
- Profile isolation started **after** committing the prior main work, as requested. Main remains the canonical project and running Godot is untouched.

## Reviewed branch tips

Each branch contains `design.md`, `scenarios.json` and `evaluation.md`. The final tip includes the proposal, intermediate cases, repair commits and review receipt; its evaluation identifies the original reviewed lines and remaining research/runtime limits.

| Profile | Branch | Final commit | Cases |
| --- | --- | --- | ---: |
| Command | `design/combat-command` | `f1087a169bbe256bc7afcbeb7c20c99128198bc2` | 19 |
| Flow | `design/combat-flow` | `1aba92f282e52c82279c775faa8c55c13ccbcac2` | 19 |
| Vanguard | `design/combat-vanguard` | `a7bb9e2a0ca4c8fa39fe1541e376e620a5775da2` | 20 |
| Oathbound | `design/combat-oathbound` | `4ee1d0652afe886430129492efa87697a51955c3` | 21 |
| Tactics | `design/combat-tactics` | `8794807800251358fc3a7196020da5d7af4610c7` | 22 |
| Momentum | `design/combat-momentum` | `9991b3af13f578927d02989fbbe0939777d415d7` | 21 |
| Confluence | `design/combat-confluence` | `beac718ad86e1f7eb8d191aed32d49fb3ac7faeb` | 17 |
| Cadence | `design/combat-cadence` | `648dbe1cc0b242d262f65ddd2090012796fd0008` | 18 |
| Orders | `design/combat-orders` | `79021413e4c2b228803548e4e8187e553b691ff4` | 16 |

## Independent review and final audit

| Profile | Independent reviewer | Accepted repair |
| --- | --- | --- |
| Command | `flow_design` | `29c9563` |
| Flow | `root` | `ee3576d` |
| Vanguard | `root` | `32bd59f` |
| Oathbound | `lcd_review` | `afa953d` |
| Tactics | `command_design` | `25c81cd` |
| Momentum | `root` | `bcbd0b6` |
| Confluence | `flow_design` | `22f710e` |
| Cadence | `lcd_review` | `c1b4abd` |
| Orders | `command_design` | `4ec2d54` |

Reviewers did not review their own authored packets. Each evaluation retains concrete counterexamples, cited findings, author repairs and a separate narrow recheck. All reported required findings are resolved within their review scopes; this is reasoned design evidence, not proof of software behavior.

The final [Git and structure audit](branch-audit.json) confirmed:

- All nine branches share the exact frozen foundation as their merge base with main.
- Each branch changes only its own three profile files; all nine worktrees are clean.
- All packets pass `tools/verify_combat_design.py`, including local links, schema and required scenario categories.
- `git diff --check design/combat-lcd..HEAD` passes in every profile worktree.
- The 173 cases are proposed acceptance obligations. They were not run as gameplay tests.

The existing runtime baseline at `e0c5006` separately passed 23 Rust tests and the catalog export check for nine profiles / 36 preview builds. That baseline does not validate these new designs. Main contains the foundation, process and final index/audit; profile proposals stay on their separate local branches. No remote push or publication was performed.

## Review locally

Start with [the shared foundation](lcd.md), then choose a profile by the play experience you want to evaluate. Each packet covers progression, world skills, equipment, inventory, ability acquisition, party behavior and economy as well as combat timing.

| Profile | Reference boundary | Defining design and interface |
| --- | --- | --- |
| Command | Knights of the Old Republic; edition differences identified | Pause and queue party actions; possess companions; populate action categories; distinguish learned powers from equipment grants and technical skills |
| Flow | Jade Empire, PC Special Edition | Direct action with four style shortcuts, Health/Chi/Focus, block/healing, transformations and one follower's attack/support modes; classless style investments and gem equipment |
| Vanguard | Mass Effect 1; Legendary Edition conveniences identified | Aim, cover, heat and individual power cooldowns; six combat/tech/biotic disciplines; order two companions; configure weapons, modules, tools and amps |
| Oathbound | Dragon Age: Origins | Four-person party, pause, companion tactics, three classes and twelve specialization designs; sustained abilities, fatigue, runes and conditional AI rules |
| Tactics | BG3 presentation; an original PF2 Remaster-inspired rules manifest | Initiative, three actions, reactions, party selection, spell preparation/repertoires, hands and Bulk; D&D and Starfinder are separate future adapters |
| Momentum | FFVII Remake; later entries distinguished | Direct action builds two ATB segments; Tactical slowdown spends them; switch actors and issue ally commands; weapon proficiency, socket links, pressure and stagger |
| Confluence | Chrono Trigger | Live readiness and moving targets; atomically commit two or three characters to joint techniques; preserve individual prerequisites, gear sources and resource claims |
| Cadence | FFVI Advance | Stable party rows, personal commands, Active/Wait selection and serialized effects; relics can replace commands, while teaching supports persistent learned abilities |
| Orders | Frozen Synapse; Prime material distinguished | Plan, preview, commit and resolve a shared interval; forecasts use only known information; RPG skills, equipment weight, ammunition and progression shape the plan |

The mandatory foundation handles identity, authority, atomic changes, durable outcomes, saves and information visibility. Profiles own their clocks, combat math, resource models, party limits and UX. Inventory, equipment and other shared capabilities are optional and replaceable. This keeps reuse from imposing one game's rules on the others.

### Open, compare or rework a packet

Each branch is checked out under `.agent-worktrees/combat-design/<id>/`. Open its `design.md`, `scenarios.json` and `evaluation.md` directly; changing the running project's branch is unnecessary.

```sh
git log --oneline design/combat-lcd..design/combat-command
git diff design/combat-lcd...design/combat-command -- docs/combat-design/profiles/command
```

For a rework, create a new branch from the desired proposal or repair commit shown in the profile's evaluation (for example, `git branch design/rework-command e81b0b5` retains the original Command proposal). Do not reset main or delete another profile's work. Cherry-picking a reviewed packet onto main later should include its proposal, acceptance cases and repairs, preserving their history; this milestone does not merge them automatically.

The structure checker proves packet shape and local link validity only. Independent evaluations are reasoned design reviews with concrete counterexamples. No in-engine combat, controller feel, camera, animation, balance or runtime save correctness is claimed by these documents.
