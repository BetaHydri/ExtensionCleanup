<#
.SYNOPSIS
  Entfernt verwaiste Edge-Extension-Referenzen aus Preferences, ohne andere Einträge zu beschädigen.

.DESCRIPTION
  - Liest installierte Extensions aus "...User Data\Default\Extensions\<extensionId>"
  - Bereinigt in der Preferences-JSON nur extension-nahe Bereiche
  - Entfernt nur IDs, die wie echte Extension-IDs aussehen (32 Zeichen, a-p)
  - Erstellt immer ein Backup vor dem Schreiben
  - Schreibt JSON wieder kompakt (wie Edge üblich)
  - Protokolliert alle Aktionen inkl. Backup-Pfade in eine Logdatei
    (Standard: %TEMP%\EdgeExtensionCleanup_<Timestamp>.log, konfigurierbar mit -LogPath)

.PARAMETER LogPath
  Pfad zur Logdatei. Standard: %TEMP%\EdgeExtensionCleanup_<Timestamp>.log.
  Die Datei wird pro Aufruf neu erstellt (kein Anhängen an bestehende Logs).

.NOTES
  Vorher Edge für den jeweiligen User schließen.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PreferencesPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences",

    [Parameter(Mandatory = $false)]
    [string]$ExtensionsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions",

    [Parameter(Mandatory = $false)]
    [string]$SecurePreferencesPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Secure Preferences",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:TEMP\EdgeExtensionCleanup_$(Get-Date -Format 'yyyyMMdd-HHmmss').log",

    [Parameter(Mandatory = $false)]
    [switch]$RemoveAllExtensionReferences
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:LogPath = $LogPath
$script:LogEncoding = New-Object System.Text.UTF8Encoding($false)

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN')]
        [string]$Level = 'INFO'
    )

    if ($Level -eq 'WARN') {
        Write-Warning $Message
    }
    else {
        Write-Host $Message
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = if ($Message -ne '') { '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message } else { '' }
    [System.IO.File]::AppendAllText($script:LogPath, "$line`r`n", $script:LogEncoding)
}

function Test-EdgeExtensionId {
    param([string]$Value)
    return ($null -ne $Value -and $Value -match '^[a-p]{32}$')
}

function Get-InstalledExtensionIds {
    param([string]$Path)

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            if (Test-EdgeExtensionId -Value $_.Name) {
                [void]$set.Add($_.Name)
            }
        }
    }
    # Komma-Operator verhindert das Entrollen der HashSet durch PowerShell.
    return , $set
}

function Invoke-CleanupNode {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Node,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [bool]$InExtensionContext,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$InstalledIds,

        [Parameter(Mandatory = $true)]
        [bool]$RemoveAllExtensionReferences,

        [Parameter(Mandatory = $true)]
        [ref]$RemovedKeys,

        [Parameter(Mandatory = $true)]
        [ref]$RemovedArrayValues
    )

    if ($null -eq $Node) {
        return $null
    }

    # Hashtable / object
    if ($Node -is [System.Collections.IDictionary]) {
        $keys = @($Node.Keys)
        foreach ($key in $keys) {
            $childPath = "$Path.$key"
            $childContext = $InExtensionContext -or ($key -match 'extension|extensions|toolbar|pinned|commands|chrome_url_overrides')

            # Nur in extension-nahem Kontext: verwaiste ext-id-Keys entfernen
            if ((Test-EdgeExtensionId -Value $key) -and (($RemoveAllExtensionReferences) -or ($childContext -and -not $InstalledIds.Contains($key)))) {
                $Node.Remove($key) | Out-Null
                $RemovedKeys.Value++
                continue
            }

            $value = $Node[$key]
            if ($value -is [string] -and (Test-EdgeExtensionId -Value $value) -and (($RemoveAllExtensionReferences) -or ($childContext -and -not $InstalledIds.Contains($value)))) {
                $Node.Remove($key) | Out-Null
                $RemovedArrayValues.Value++
                continue
            }

            $Node[$key] = Invoke-CleanupNode -Node $Node[$key] -Path $childPath -InExtensionContext $childContext `
                -InstalledIds $InstalledIds -RemoveAllExtensionReferences $RemoveAllExtensionReferences `
                -RemovedKeys $RemovedKeys -RemovedArrayValues $RemovedArrayValues
        }
        return $Node
    }

    # Arrays / lists
    if ($Node -is [System.Collections.IList]) {
        $cleanList = [System.Collections.ArrayList]::new()
        for ($i = 0; $i -lt $Node.Count; $i++) {
            $item = $Node[$i]

            # Nur in extension-nahem Kontext: verwaiste ext-id-Stringwerte entfernen
            if ($item -is [string] -and (Test-EdgeExtensionId -Value $item) -and (($RemoveAllExtensionReferences) -or ($InExtensionContext -and -not $InstalledIds.Contains($item)))) {
                $RemovedArrayValues.Value++
                continue
            }

            $cleanItem = Invoke-CleanupNode -Node $item -Path "$Path[$i]" -InExtensionContext $InExtensionContext `
                -InstalledIds $InstalledIds -RemoveAllExtensionReferences $RemoveAllExtensionReferences `
                -RemovedKeys $RemovedKeys -RemovedArrayValues $RemovedArrayValues
            [void]$cleanList.Add($cleanItem)
        }
        return $cleanList
    }

    return $Node
}

$installed = Get-InstalledExtensionIds -Path $ExtensionsPath

function ConvertTo-HashtableDeep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        [object]$InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $ht = @{}
            foreach ($prop in $InputObject.PSObject.Properties) {
                $ht[$prop.Name] = ConvertTo-HashtableDeep -InputObject $prop.Value
            }
            return $ht
        }

        if ($InputObject -is [System.Collections.IList] -and $InputObject -isnot [string]) {
            $list = [System.Collections.ArrayList]::new()
            foreach ($item in $InputObject) {
                [void]$list.Add((ConvertTo-HashtableDeep -InputObject $item))
            }
            return $list
        }

        return $InputObject
    }
}

function Invoke-CleanupFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$InstalledIds,

        [Parameter(Mandatory = $true)]
        [bool]$RemoveAll
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log "Datei nicht gefunden, übersprungen: $Path" -Level 'WARN'
        return
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$Path.bak.$timestamp"
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $json = $raw | ConvertFrom-Json -AsHashtable -Depth 100
    }
    else {
        $json = $raw | ConvertFrom-Json | ConvertTo-HashtableDeep
    }

    $removedKeys = 0
    $removedArrayValues = 0

    $json = Invoke-CleanupNode -Node $json -Path '$' -InExtensionContext $false `
        -InstalledIds $InstalledIds -RemoveAllExtensionReferences $RemoveAll `
        -RemovedKeys ([ref]$removedKeys) -RemovedArrayValues ([ref]$removedArrayValues)

    $out = $json | ConvertTo-Json -Depth 100 -Compress
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $out, $utf8NoBom)

    Write-Log "Datei   : $Path"
    Write-Log "Backup  : $backupPath"
    Write-Log "Entfernte Schlüssel (ID-Keys)     : $removedKeys"
    Write-Log "Entfernte Array-Werte (ID-Strings): $removedArrayValues"
    Write-Log ''
}

Write-Log '=== EdgeExtensionCleanup ==='
Write-Log "Benutzer   : $env:USERNAME"
Write-Log "Computer   : $env:COMPUTERNAME"
Write-Log "PowerShell : $($PSVersionTable.PSVersion)"
Write-Log "Protokoll  : $($script:LogPath)"
Write-Log ''
Write-Log "Installierte Extension-IDs : $($installed.Count)"
Write-Log "Modus                      : $(if ($RemoveAllExtensionReferences) { 'Alle Extension-Verweise' } else { 'Nur verwaiste Extension-Verweise' })"
Write-Log ''

Invoke-CleanupFile -Path $PreferencesPath -InstalledIds $installed -RemoveAll ([bool]$RemoveAllExtensionReferences)
Invoke-CleanupFile -Path $SecurePreferencesPath -InstalledIds $installed -RemoveAll ([bool]$RemoveAllExtensionReferences)
Write-Log ''
Write-Log '=== Bereinigung abgeschlossen ==='