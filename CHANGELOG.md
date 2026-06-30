# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/BetaHydri/ExtensionCleanup/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/BetaHydri/ExtensionCleanup/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/BetaHydri/ExtensionCleanup/releases/tag/v1.0.0
