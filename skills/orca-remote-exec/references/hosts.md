# Paired execution hosts

Machine-specific facts. Update this file when a host's toolchain or paths
change, in the same change that installs or upgrades the tool.

## mac mini

| Field | Value |
|---|---|
| Orca environment | `mac mini` (`orca host list` → `--environment "mac mini"`) |
| Endpoint | `ws://100.68.166.8:6768` (Tailscale; must be connected) |
| Hardware | macOS 27.0, 32 GB, 12 cores |
| Remote user | `geonseok.lee` |
| Agents | none — execution only |
| `MM_REPO` default | `/Users/geonseok.lee/Workspace/ma/ma-client` (git, `themoin/ma-client`) |
| git / gh | `/usr/bin/git`; `gh` at `/opt/homebrew/bin/gh`, logged in as `geonseokleee` |
| Flutter | via fvm only — fvm 4.3.2 (Homebrew `leoafarias/fvm`); SDK 3.47.8 / Dart 3.13.7 cached in `~/fvm/versions`. Do not install a global Flutter; a tree's `.fvmrc` selects the SDK. |
| Python | uv 0.13.6 (Homebrew) |
| Installed | 2026-10-29, at the user's request |

Measured on 2026-10-29 with `release/5.22.0` (`72d26e0`):

| Step | Result |
|---|---|
| base tree + `pub get` (cold pub cache) | 38 s |
| base tree + `pub get` (warm cache) | 11 s |
| `--clone-from` (APFS clone, 248 MB tree) | 7 s |
| full `dart format` gate | 10 s, 0 changed |
| `test/app/benefit_badge` + `test/router` | 253 passed, 27 s |
| three concurrent runs (`test/router` ×2 incl. one clone, `test/app`) | all passed, 37 s wall |

`.dart_tool/package_config.json` uses relative workspace paths, so a cloned tree
resolves its own packages without a new `pub get`.

Known quirks:

- Orca also lists a folder `/Users/geonseo.lee/Workspace/ma/ma-client` for this
  environment. That path does not exist (typo registration); ignore it.
- `fvm install` in the repository creates the git-ignored `.fvm/` and updates
  `.vscode/settings.json`. Both are ignored by git, so the checkout stays clean.
- Orca keeps a terminal titled `Terminal 1` on this environment that the
  scripts did not create; leave it.
- A tree's first `fvm flutter pub get` fills the remote pub cache; later trees
  are faster.
