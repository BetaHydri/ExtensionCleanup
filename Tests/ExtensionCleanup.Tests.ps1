#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'ExtensionCleanup.ps1' {
    BeforeAll {
        $script:ScriptPath = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') 'ExtensionCleanup.ps1')).Path
        $script:InstalledId = 'abcdefghijklmnopabcdefghijklmnop'
        $script:OrphanId = 'ponmlkjihgfedcbaponmlkjihgfedcba'
        $script:OrphanId2 = 'lmnopabcdefghijklmnopabcdefghijk'

        function New-MockProfile {
            param(
                [Parameter(Mandatory)] [string]$Root,
                [Parameter(Mandatory)] [string]$ProfileFolder,
                [switch]$IncludeOrphans,
                [switch]$NoExtensionsFolder
            )

            $profileDir = Join-Path $Root $ProfileFolder
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

            if (-not $NoExtensionsFolder) {
                $extDir = Join-Path $profileDir "Extensions\$script:InstalledId"
                New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            }

            $prefs = [ordered]@{
                browser    = [ordered]@{
                    last_known_google_url = 'https://example.invalid'
                }
                extensions = [ordered]@{
                    settings          = [ordered]@{
                        $script:InstalledId = [ordered]@{ name = 'Installed' }
                    }
                    pinned_extensions = @($script:InstalledId)
                    toolbar           = @($script:InstalledId)
                }
            }
            if ($IncludeOrphans) {
                $prefs.extensions.settings[$script:OrphanId] = [ordered]@{ name = 'Orphan' }
                $prefs.extensions.settings[$script:OrphanId2] = [ordered]@{ name = 'Orphan2' }
                $prefs.extensions.pinned_extensions = @($script:InstalledId, $script:OrphanId)
                $prefs.extensions.toolbar = @($script:InstalledId, $script:OrphanId2)
            }

            $secure = [ordered]@{
                protection = [ordered]@{
                    macs = [ordered]@{
                        extensions = [ordered]@{
                            settings = [ordered]@{
                                $script:InstalledId = 'mac-installed'
                            }
                        }
                    }
                }
            }
            if ($IncludeOrphans) {
                $secure.protection.macs.extensions.settings[$script:OrphanId] = 'mac-orphan'
            }

            ($prefs | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath (Join-Path $profileDir 'Preferences')        -Encoding UTF8
            ($secure | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath (Join-Path $profileDir 'Secure Preferences') -Encoding UTF8

            return $profileDir
        }

        function Get-Pref {
            param([Parameter(Mandatory)] [string]$Path)
            $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                return ($raw | ConvertFrom-Json -AsHashtable -Depth 100)
            }
            else {
                # Convert PSCustomObject -> hashtable to allow ContainsKey on PS 5.1
                $obj = $raw | ConvertFrom-Json
                $ht = @{}
                foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
                return $ht
            }
        }
    }

    Context 'Single default profile' {
        BeforeAll {
            $script:UserData = Join-Path $TestDrive 'SingleDefault'
            $script:DefDir = New-MockProfile -Root $script:UserData -ProfileFolder 'Default' -IncludeOrphans
            $script:LogFile = Join-Path $TestDrive 'single-default.log'

            & $script:ScriptPath -UserDataPath $script:UserData -LogPath $script:LogFile
        }

        It 'creates a log file' {
            Test-Path -LiteralPath $script:LogFile | Should -BeTrue
        }

        It 'creates a backup of Preferences' {
            (Get-ChildItem -LiteralPath $script:DefDir -Filter 'Preferences.bak.*').Count | Should -BeGreaterThan 0
        }

        It 'removes orphan extension keys from Preferences' {
            $p = Get-Pref -Path (Join-Path $script:DefDir 'Preferences')
            $settings = $p.extensions.settings
            # Convert to hashtable-like contains check (compat: PS5.1 PSCustomObject vs PS7 hashtable)
            $names = @($settings.PSObject.Properties.Name) + @($settings.Keys)
            $names | Should -Contain $script:InstalledId
            $names | Should -Not -Contain $script:OrphanId
            $names | Should -Not -Contain $script:OrphanId2
        }

        It 'removes orphan IDs from pinned_extensions array' {
            $p = Get-Pref -Path (Join-Path $script:DefDir 'Preferences')
            $p.extensions.pinned_extensions | Should -Contain $script:InstalledId
            $p.extensions.pinned_extensions | Should -Not -Contain $script:OrphanId
        }

        It 'preserves unrelated browser settings' {
            $p = Get-Pref -Path (Join-Path $script:DefDir 'Preferences')
            $p.browser.last_known_google_url | Should -Be 'https://example.invalid'
        }

        It 'removes orphan from Secure Preferences protection.macs' {
            $sec = Get-Pref -Path (Join-Path $script:DefDir 'Secure Preferences')
            $settings = $sec.protection.macs.extensions.settings
            $names = @($settings.PSObject.Properties.Name) + @($settings.Keys)
            $names | Should -Contain $script:InstalledId
            $names | Should -Not -Contain $script:OrphanId
        }

        It 'logs the profile header' {
            (Get-Content -LiteralPath $script:LogFile -Raw) | Should -Match '=== Profil: Default ==='
        }
    }

    Context 'Multiple explicit profiles' {
        BeforeAll {
            $script:UserData2 = Join-Path $TestDrive 'MultiExplicit'
            $script:Def2 = New-MockProfile -Root $script:UserData2 -ProfileFolder 'Default' -IncludeOrphans
            $script:P1 = New-MockProfile -Root $script:UserData2 -ProfileFolder 'Profile 1' -IncludeOrphans
            $null = New-MockProfile -Root $script:UserData2 -ProfileFolder 'Profile 2' -IncludeOrphans
            $script:LogFile2 = Join-Path $TestDrive 'multi-explicit.log'

            & $script:ScriptPath -UserDataPath $script:UserData2 -ProfileName 'Default', 'Profile 1' -LogPath $script:LogFile2
        }

        It 'cleans the named profiles' {
            foreach ($dir in @($script:Def2, $script:P1)) {
                $p = Get-Pref -Path (Join-Path $dir 'Preferences')
                $names = @($p.extensions.settings.PSObject.Properties.Name) + @($p.extensions.settings.Keys)
                $names | Should -Not -Contain $script:OrphanId
                $names | Should -Contain $script:InstalledId
            }
        }

        It 'does NOT touch unlisted profile (Profile 2)' {
            $p = Get-Pref -Path (Join-Path $script:UserData2 'Profile 2\Preferences')
            $names = @($p.extensions.settings.PSObject.Properties.Name) + @($p.extensions.settings.Keys)
            $names | Should -Contain $script:OrphanId
        }

        It 'logs both profile headers' {
            $content = Get-Content -LiteralPath $script:LogFile2 -Raw
            $content | Should -Match '=== Profil: Default ==='
            $content | Should -Match '=== Profil: Profile 1 ==='
            $content | Should -Not -Match '=== Profil: Profile 2 ==='
        }
    }

    Context '-AllProfiles discovery' {
        BeforeAll {
            $script:UserData3 = Join-Path $TestDrive 'AllProfiles'
            $script:DefA = New-MockProfile -Root $script:UserData3 -ProfileFolder 'Default' -IncludeOrphans
            $script:P1A = New-MockProfile -Root $script:UserData3 -ProfileFolder 'Profile 1' -IncludeOrphans
            $script:SysA = New-MockProfile -Root $script:UserData3 -ProfileFolder 'System Profile' -IncludeOrphans
            $script:GstA = New-MockProfile -Root $script:UserData3 -ProfileFolder 'Guest Profile' -IncludeOrphans
            # Cache-style folder without Preferences must be ignored
            New-Item -ItemType Directory -Path (Join-Path $script:UserData3 'ShaderCache') -Force | Out-Null

            $script:LogFile3 = Join-Path $TestDrive 'all-profiles.log'
            & $script:ScriptPath -UserDataPath $script:UserData3 -AllProfiles -LogPath $script:LogFile3
        }

        It 'cleans Default and Profile 1' {
            foreach ($dir in @($script:DefA, $script:P1A)) {
                $p = Get-Pref -Path (Join-Path $dir 'Preferences')
                $names = @($p.extensions.settings.PSObject.Properties.Name) + @($p.extensions.settings.Keys)
                $names | Should -Not -Contain $script:OrphanId
            }
        }

        It 'skips System Profile and Guest Profile (orphans still present)' {
            foreach ($dir in @($script:SysA, $script:GstA)) {
                $p = Get-Pref -Path (Join-Path $dir 'Preferences')
                $names = @($p.extensions.settings.PSObject.Properties.Name) + @($p.extensions.settings.Keys)
                $names | Should -Contain $script:OrphanId
            }
        }

        It 'logs skipped system/guest profiles are absent from the run header' {
            $content = Get-Content -LiteralPath $script:LogFile3 -Raw
            $content | Should -Match '=== Profil: Default ==='
            $content | Should -Match '=== Profil: Profile 1 ==='
            $content | Should -Not -Match '=== Profil: System Profile ==='
            $content | Should -Not -Match '=== Profil: Guest Profile ==='
        }
    }

    Context 'Legacy explicit -PreferencesPath' {
        BeforeAll {
            $script:UserData4 = Join-Path $TestDrive 'Legacy'
            $script:DefL = New-MockProfile -Root $script:UserData4 -ProfileFolder 'Default' -IncludeOrphans
            $script:OtherL = New-MockProfile -Root $script:UserData4 -ProfileFolder 'Profile 1' -IncludeOrphans
            $script:LogFile4 = Join-Path $TestDrive 'legacy.log'

            & $script:ScriptPath `
                -PreferencesPath       (Join-Path $script:DefL 'Preferences') `
                -SecurePreferencesPath (Join-Path $script:DefL 'Secure Preferences') `
                -ExtensionsPath        (Join-Path $script:DefL 'Extensions') `
                -LogPath $script:LogFile4
        }

        It 'cleans the explicit target only' {
            $p = Get-Pref -Path (Join-Path $script:DefL 'Preferences')
            $names = @($p.extensions.settings.PSObject.Properties.Name) + @($p.extensions.settings.Keys)
            $names | Should -Not -Contain $script:OrphanId
        }

        It 'does not touch other profiles' {
            $p = Get-Pref -Path (Join-Path $script:OtherL 'Preferences')
            $names = @($p.extensions.settings.PSObject.Properties.Name) + @($p.extensions.settings.Keys)
            $names | Should -Contain $script:OrphanId
        }
    }

    Context 'Profile with zero installed extensions' {
        BeforeAll {
            $script:UserData5 = Join-Path $TestDrive 'ZeroInstalled'
            $script:Def0 = New-MockProfile -Root $script:UserData5 -ProfileFolder 'Default' -IncludeOrphans -NoExtensionsFolder
            $script:LogFile5 = Join-Path $TestDrive 'zero.log'

            & $script:ScriptPath -UserDataPath $script:UserData5 -LogPath $script:LogFile5
        }

        It 'completes without error and writes a log' {
            Test-Path -LiteralPath $script:LogFile5 | Should -BeTrue
            (Get-Content -LiteralPath $script:LogFile5 -Raw) | Should -Match 'Installierte Extension-IDs : 0'
        }

        It 'removes the previously-installed ID as orphan too (no installed dir = nothing installed)' {
            $p = Get-Pref -Path (Join-Path $script:Def0 'Preferences')
            $names = @($p.extensions.settings.PSObject.Properties.Name) + @($p.extensions.settings.Keys)
            $names | Should -Not -Contain $script:InstalledId
            $names | Should -Not -Contain $script:OrphanId
        }
    }

    Context 'Non-existent profile name' {
        BeforeAll {
            $script:UserData6 = Join-Path $TestDrive 'Missing'
            New-Item -ItemType Directory -Path $script:UserData6 -Force | Out-Null
            $script:LogFile6 = Join-Path $TestDrive 'missing.log'
        }

        It 'logs a warning but does not throw' {
            { & $script:ScriptPath -UserDataPath $script:UserData6 -ProfileName 'DoesNotExist' -LogPath $script:LogFile6 } | Should -Not -Throw
            (Get-Content -LiteralPath $script:LogFile6 -Raw) | Should -Match 'Profilordner nicht gefunden'
        }
    }
}
