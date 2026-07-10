# Changelog

## 0.9.2 - 2026-07-11

- Fixed the prompt marker not changing from `#` to `$` immediately after `psx .`.
- Registration and unregistration now invalidate the location/context cache and reapply the current context immediately.


## 0.9.2

- Unified the public command name to `psx` and removed legacy wrapper commands.
- Removed PSReadLine history clear/replay during directory changes.
- Added directory/context caching to avoid repeated parent-folder scans.
- Added history deduplication and a 1,000-entry retention limit.
- Compacts matching timestamp metadata and keeps the newest duplicate entry.

## 0.8.2

- Fixed a noisy profile reload message when alias `h` had already been removed.
- `h` is now removed only when `Alias:h` exists.

## 0.8.1

- Added `psx --v` to show both PowerShell and PSX versions.
- Added `psx /version`, `psx -v`, `psxv`, and `psx` runtime helpers.
- Added `psx.ps1` and `psx.cmd` as short command entry points.


## v0.1.0

Initial public-ready package.

- Fixed recommended command name to `psx`
- Kept only `psx` as the public command
- Added project-local PSReadLine history switching
- Added up/down-key history isolation
- Added `.psctx.json` project config
- Added prompt markers: gray `# ` for unmanaged folders, white `$ ` for managed folders
- Added `h` history list with DateTime
- Added `!<id>` and `! <id>` history replay
- Added optional trailing `&` background job support
- Added install/uninstall scripts
- Added Japanese and English README content
- Added note article draft
- Added MIT License
