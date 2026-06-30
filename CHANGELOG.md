# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New `-Force` switch (available in every parameter set). Bypasses the
  pre-flight "Edge running in this session" gate and stops every
  `msedge.exe` process in the current user session before cleanup.
- Pre-flight gate: before any profile is touched, the script checks
  whether `msedge.exe` runs in the **current** user session
  (`Get-Process msedge` filtered by `SessionId == $PID.SessionId`). If
  yes and `-Force` is not set, the script logs a `WARN`, prints a hint
  and exits cleanly with code `0` instead of crashing on locked JSON
  files. The gate is skipped in the `Legacy` parameter set so explicit
  paths to offline-backed-up profiles still work.
- New internal helpers `Test-EdgeRunningInCurrentSession` and
  `Stop-EdgeInCurrentSession`. The detection helper honors a test hook
  via `$env:EDGECLEANUP_TEST_EDGE_RUNNING` (`'1'` = simulate running,
  `'0'` = simulate not running, unset = real detection) so the Pester
  suite can validate both branches deterministically on developer
  machines that have Edge open.
- New `Force : <True|False>` line in the run-log header for
  traceability.
- Seven additional Pester tests under
  `Tests\ExtensionCleanup.Tests.ps1`:
  - `Context 'Pre-flight: Edge running in current session'` (3 tests):
    blocked run logs the WARN + still reaches the closing footer +
    leaves the orphan in place; `-Force` run kills msedge and removes
    the orphan; `Force : True` appears in the run-log header.
  - `Context 'Per-file lock resilience (Preferences locked, Secure
    Preferences free)'` (4 tests): a hard OS-level exclusive lock on
    `Preferences` (`[System.IO.File]::Open(..., 'Open', 'Read', 'None')`)
    produces a per-file `WARN`, the run still finishes with the footer,
    a skip-summary line is logged, and the unlocked
    `Secure Preferences` is cleaned in the same run.
- New `ParamSet : <ByProfile|AllProfiles|Legacy>` line in the run-log
  header for traceability (carried over from the parameter-set
  refactor).
- Six earlier Pester tests under
  `Tests\ExtensionCleanup.Tests.ps1` (`Context 'Parameter sets'`):
  three happy-path tests confirming the correct set is logged for each
  invocation style, plus three rejection tests that assert
  `AmbiguousParameterSet,ExtensionCleanup.ps1` is thrown when
  parameters from different sets are combined.

### Changed

- `Invoke-CleanupFile` now returns `[bool]` (`$true` on successful
  rewrite, `$false` on skip / lock / missing file). The main loop
  counts the `$false` returns and emits a single summary line
  (`Hinweis: N Datei(en) wurden ausgelassen ...`) at the end.
- `Invoke-CleanupFile` wraps its read / backup / write steps in a
  `try / catch [System.IO.IOException]` plus
  `catch [System.UnauthorizedAccessException]`. A lock on one file no
  longer aborts the whole run; the other files in the same profile and
  all remaining profiles are still processed.
- Enforce mutually exclusive parameter sets `ByProfile` (default),
  `AllProfiles`, and `Legacy`. Combining parameters from different sets
  (e.g. `-ProfileName` with `-PreferencesPath`, `-AllProfiles` with
  `-PreferencesPath`, or `-ProfileName` with `-AllProfiles`) now fails
  fast with PowerShell's native `AmbiguousParameterSet` error instead
  of being silently resolved by runtime precedence on
  `$PSBoundParameters`.
- `-AllProfiles` and `-PreferencesPath` are declared `Mandatory` inside
  their respective sets, so PowerShell selects the correct set
  unambiguously without runtime sniffing.
- `ExtensionCleanup.ps1` is now saved as **UTF-8 with BOM**. Windows
  PowerShell 5.1 was decoding the previous BOM-less file as Windows-1252,
  which double-encoded German umlauts (`ä`, `ö`, `ü`, `ß`) in
  `WARN`/`INFO` log lines and broke any tooling that grep-matched on
  those strings. PS 7 was unaffected. No semantic source change.

### Fixed

- Ivanti error 17 / `IOException 0x80070020` ("Der Prozess kann nicht
  auf die Datei zugreifen, da sie von einem anderen Prozess verwendet
  wird") when Edge happens to be running during a scheduled or logoff
  cleanup. The script now either skips cleanly with `WARN` + Exit 0
  (default) or terminates the offending `msedge.exe` instances first
  (`-Force`). A late-arriving per-file lock during the run is reported
  per file and the run still completes with Exit 0.

### Verified

- Full Pester suite (31 tests) green on Windows PowerShell 5.1 and
  PowerShell 7.6.

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
