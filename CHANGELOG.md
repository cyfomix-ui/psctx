# Changelog

## 0.7.1

- Added `psx --v` to show PowerShell and PSCtx versions together.
- Added `psctx /version`, `psctx -v`, and `psctxv`.
- Fixed an internal variable collision with PowerShell `$PSEdition`.
- Documented PowerShell 5.1 and PowerShell 7.x profile differences.

## 0.7.0

- Added version display commands.
- Added GitHub-ready README and documentation structure.

## 0.6.0

- Added date and time display to PSCtx history output.
- Added timestamp recording through PSCtx JSONL history metadata.
- Fixed `!5` and `! 5` handling.

## 0.5.0

- Added `h` history display.
- Added history replay by ID.
- Aligned `h` IDs with PSCtx history replay IDs.

## 0.4.0

- Added prompt markers.
- Unmanaged folders show `# `.
- Managed project folders show `$ `.

## 0.3.0

- Added Bash-like trailing `&` helper through PowerShell jobs.
- Added `bgjobs`, `bgout`, and `bgkill` helpers.

## 0.2.0

- Added per-project PSReadLine history path switching.
- Added Up/Down arrow history separation by reloading PSReadLine memory.

## 0.1.0

- Initial PSCtx concept.
- Added project registration through `.psctx.ps1`.
- Added project-local environment variable support.
