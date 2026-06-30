# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-06-30

### Added

- Multi-profile support. The script now processes one, several, or all
  Edge profiles in a single run:
  - `-UserDataPath <string>` — root of all Edge profiles
    (default: `%LOCALAPPDATA%\Microsoft\Edge\User Data`).
  - `-ProfileName <string[]>` — one or more profile folder names
    (e.g. `'Default','Profile 1','Profile 2'`). Default: `'Default'`.
  - `-AllProfiles` — auto-discover every profile folder under
    `-UserDataPath` that contains a `Preferences` file. `System Profile`
    and `Guest Profile` (and known cache folders such as `ShaderCache`)
    are excluded.
- Per-profile section header in the run log
  (`=== Profil: <Name> ===`) plus a summary line listing the profiles
  that will be processed.
- Pester 5 test suite under `Tests\ExtensionCleanup.Tests.ps1` covering
  single profile, multiple named profiles, `-AllProfiles` discovery
  (with System/Guest exclusion), legacy explicit paths, zero installed
  extensions, and a non-existent profile name.

### Changed

- The legacy parameters `-PreferencesPath`, `-SecurePreferencesPath`, and
  `-ExtensionsPath` are now optional and only take precedence when
  explicitly bound. If any of them is set, the script switches to
  single-target legacy mode and skips profile discovery; otherwise the
  new `-UserDataPath` / `-ProfileName` / `-AllProfiles` path is used.

### Verified

- Pester suite (18 tests) green on Windows PowerShell 5.1 and PowerShell
  7.6: single profile, multiple named profiles, `-AllProfiles` with
  `System Profile` and `Guest Profile` present (correctly skipped),
  legacy explicit-path mode, zero-installed and non-existent-profile
  edge cases.

### Added

- New `-LogPath` parameter and run-level logging via a `Write-Log` helper.
  Every action (header with user/computer/PS version, per-file work, backup
  paths, removed-key/value counts, warnings, footer) is written to a UTF-8
  log file. Default path:
  `%TEMP%\EdgeExtensionCleanup_<yyyyMMdd-HHmmss>.log`.
  The log file is created fresh on every run (no append).

### Fixed

- `Get-InstalledExtensionIds` now returns the `HashSet` reliably via the
  comma operator (`return , $set`). PowerShell previously unrolled the
  enumerable, which silently turned the return value into a bare string
  when exactly one extension was installed and broke the orphan check
  under `Set-StrictMode -Version Latest`.
- `Invoke-CleanupFile` and `Invoke-CleanupNode` accept an empty
  `InstalledIds` HashSet (`[AllowEmptyCollection()]`). Running on a profile
  with zero installed extensions no longer aborts with
  `ParameterArgumentValidationErrorEmptyCollectionNotAllowed`.
- Refined `ConvertTo-HashtableDeep` to a proper advanced function with
  `[CmdletBinding()]`, `ValueFromPipeline`, and a `process` block, so the
  PS 5.1 pipeline call (`... | ConvertFrom-Json | ConvertTo-HashtableDeep`)
  binds cleanly instead of failing with `InputObjectNotBound`.

### Verified

- End-to-end runtime test matrix passes on Windows PowerShell 5.1 and
  PowerShell 7.6 for 0, 1, and multiple installed extensions: orphan
  removed, installed kept, unrelated JSON sections preserved.

## [1.1.0] - 2026-06-30

### Fixed

- Script now runs on **Windows PowerShell 5.1** as well as PowerShell 7+.
  `ConvertFrom-Json -AsHashtable` and `-Depth` are not available in PS 5.1.
  Added `ConvertTo-HashtableDeep` helper that recursively converts the
  `PSCustomObject` tree returned by PS 5.1's `ConvertFrom-Json` into a plain
  `Hashtable`/`ArrayList` structure, which is required for the `IDictionary`
  check inside `Invoke-CleanupNode`.
- Removed `#Requires -Version 7.0` restriction that blocked execution on
  Windows Server 2022 systems without PowerShell 7 installed.

## [1.0.0] - 2026-06-30

### Added

- Initial release of `ExtensionCleanup.ps1`.
- Reads installed Edge extensions from `User Data\Default\Extensions\<id>`.
- Cleans orphaned extension references from `Preferences` and
  `Secure Preferences` JSON files without touching unrelated entries.
- Only removes keys/values that match the Edge extension-ID pattern
  (32 lowercase characters, `a`–`p`).
- Operates in two modes:
  - Default: removes only **orphaned** references (IDs not present in the
    Extensions folder) within extension-adjacent JSON sections.
  - `-RemoveAllExtensionReferences`: removes **all** extension-ID references
    regardless of install state.
- Creates a timestamped backup (`.bak.YYYYMMDD-HHmmss`) before writing.
- Writes output JSON compact and UTF-8 without BOM, matching Edge's own format.
- Usage examples for terminal-server / Ivanti logoff scenarios added to README.

[Unreleased]: https://github.com/BetaHydri/ExtensionCleanup/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/BetaHydri/ExtensionCleanup/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/BetaHydri/ExtensionCleanup/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/BetaHydri/ExtensionCleanup/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/BetaHydri/ExtensionCleanup/releases/tag/v1.0.0
