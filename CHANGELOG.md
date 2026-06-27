# Changelog

## 0.8.2

- Fixed a noisy profile reload message when alias `h` had already been removed.
- `h` is now removed only when `Alias:h` exists.

## 0.8.1

- Added `psx --v` to show both PowerShell and PSCtx versions.
- Added `psctx /version`, `psctx -v`, `psctxv`, and `psx` runtime helpers.
- Added `psx.ps1` and `psx.cmd` as short command entry points.


## v0.1.0

Initial public-ready package.

- Fixed recommended command name to `psctx`
- Kept `pph` and `psprojhist` as backward-compatible aliases
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
