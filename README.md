# Microsoft Edge ExtensionCleanup

PowerShell-Skript zum Bereinigen von Edge-Extension-Verweisen in den
Profildateien eines Benutzers.

Das Skript erstellt vor jeder Änderung automatisch ein Backup und schreibt
anschließend die JSON-Datei kompakt zurück.

## Was das Skript macht

`ExtensionCleanup.ps1` verarbeitet aktuell diese Dateien:

- `Preferences`
- `Secure Preferences`

Dabei werden Einträge entfernt, die wie Edge-Extension-IDs aussehen
(`^[a-p]{32}$`), abhängig vom gewählten Modus:

- Standardmodus: nur verwaiste Referenzen
- Vollmodus (`-RemoveAllExtensionReferences`): alle gefundenen
  Extension-ID-Referenzen

## Voraussetzungen

- Windows mit Microsoft Edge-Profil
- PowerShell (Windows PowerShell oder PowerShell 7)
- Edge sollte vor dem Lauf geschlossen sein

## Standardpfade

Ohne Parameter nutzt das Skript:

- `UserDataPath`:  
  `C:\Users\<User>\AppData\Local\Microsoft\Edge\User Data`
- Verarbeitetes Profil: `Default`  
  (`<UserDataPath>\Default\Preferences`,
  `<UserDataPath>\Default\Secure Preferences`,
  `<UserDataPath>\Default\Extensions`)

Mit `-AllProfiles` werden zusätzlich `Profile 1`, `Profile 2`, … erkannt;
`System Profile`, `Guest Profile` und bekannte Cache-Ordner werden dabei
automatisch übersprungen.

## Parameter

- `-UserDataPath <string>`  
  Wurzel aller Edge-Profile.  
  Standard: `%LOCALAPPDATA%\Microsoft\Edge\User Data`.
- `-ProfileName <string[]>`  
  Ein oder mehrere Profilordnernamen unterhalb von `-UserDataPath`
  (z. B. `'Default'`, `'Profile 1'`, `'Profile 2'`).  
  Standard: `'Default'`.
- `-AllProfiles`  
  Verarbeitet automatisch alle erkannten Profile unter `-UserDataPath`,
  die eine `Preferences`-Datei enthalten. `System Profile`,
  `Guest Profile` und bekannte Cache-Ordner werden ausgeschlossen.
- `-PreferencesPath <string>` *(Legacy / einzelnes Profil)*  
  Expliziter Pfad zur Datei `Preferences`. Wenn gesetzt, wird die
  Profil-Auto-Erkennung deaktiviert und nur dieses eine Ziel verarbeitet.
- `-SecurePreferencesPath <string>` *(Legacy / einzelnes Profil)*  
  Expliziter Pfad zur Datei `Secure Preferences`.
- `-ExtensionsPath <string>` *(Legacy / einzelnes Profil)*  
  Expliziter Pfad zum `Extensions`-Ordner (Vergleichsbasis im
  Standardmodus).
- `-RemoveAllExtensionReferences`  
  Schaltet auf Vollmodus um.
- `-LogPath <string>`  
  Pfad zur Logdatei für diesen Lauf. Standardwert:
  `%TEMP%\EdgeExtensionCleanup_<yyyyMMdd-HHmmss>.log`.
  Die Datei wird bei jedem Lauf neu erstellt (kein Append).

Die drei Legacy-Parameter (`-PreferencesPath`, `-SecurePreferencesPath`,
`-ExtensionsPath`) haben Vorrang: sobald einer davon explizit gesetzt
ist, ignoriert das Skript `-UserDataPath` / `-ProfileName` /
`-AllProfiles` und arbeitet ausschließlich auf den angegebenen Pfaden.

## Beispiele

### 1) Standardlauf (empfohlen)

Entfernt nur verwaiste Verweise im Profil `Default`:

```powershell
.\ExtensionCleanup.ps1
```

### 2) Vollbereinigung im Profil `Default`

Entfernt alle Extension-ID-Verweise in `Preferences` und
`Secure Preferences`:

```powershell
.\ExtensionCleanup.ps1 -RemoveAllExtensionReferences
```

### 3) Alle Edge-Profile in einem Lauf bereinigen

Verarbeitet automatisch `Default`, `Profile 1`, `Profile 2`, …:

```powershell
.\ExtensionCleanup.ps1 -AllProfiles
```

### 4) Mehrere benannte Profile gezielt bereinigen

```powershell
.\ExtensionCleanup.ps1 -ProfileName 'Default','Profile 1','Profile 2'
```

### 5) Eigener `User Data`-Pfad (z. B. Backup)

```powershell
.\ExtensionCleanup.ps1 `
  -UserDataPath 'D:\EdgeBackup\User Data' `
  -AllProfiles
```

### 6) Benutzerdefinierte Profilpfade (Legacy)

Wenn ein Profil aus historischen Gründen außerhalb der Standardstruktur
liegt, können die Pfade direkt gesetzt werden:

```powershell
.\ExtensionCleanup.ps1 `
  -PreferencesPath 'D:\Profiles\Edge\Default\Preferences' `
  -SecurePreferencesPath 'D:\Profiles\Edge\Default\Secure Preferences' `
  -ExtensionsPath 'D:\Profiles\Edge\Default\Extensions'
```

### 7) Lauf mit eigener Logdatei

Schreibt das vollständige Lauf-Protokoll in eine eigene Datei statt in
`%TEMP%`:

```powershell
.\ExtensionCleanup.ps1 -LogPath 'D:\Logs\EdgeCleanup\Cleanup.log'
```

Lässt sich beliebig mit den anderen Parametern kombinieren, z. B.:

```powershell
.\ExtensionCleanup.ps1 `
  -AllProfiles `
  -RemoveAllExtensionReferences `
  -LogPath "D:\Logs\EdgeCleanup\$env:USERNAME-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
```

## Einsatz auf Terminalservern beim Abmelden

Auf RDS-/Terminalservern kann das Skript beim Benutzer-Logoff ausgeführt
werden, um Profilreste regelmäßig zu bereinigen.

### Variante A: Logoff-Skript pro Benutzerkontext

Wenn das Skript im Benutzerkontext läuft, reichen die Standardpfade aus,
weil `$env:LOCALAPPDATA` automatisch auf das aktuelle Benutzerprofil zeigt.

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' `
  -NoProfile -ExecutionPolicy Bypass -File `
  'C:\Scripts\ExtensionCleanup\ExtensionCleanup.ps1' `
  -LogPath "\\fileserver\Logs$\EdgeCleanup\$env:USERNAME-$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
```

Optional im Vollmodus:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' `
  -NoProfile -ExecutionPolicy Bypass -File `
  'C:\Scripts\ExtensionCleanup\ExtensionCleanup.ps1' `
  -RemoveAllExtensionReferences `
  -LogPath "\\fileserver\Logs$\EdgeCleanup\$env:USERNAME-$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
```

### Variante B: Zentraler Aufruf für ein bestimmtes Benutzerprofil

Wenn zentral (z. B. durch einen administrativen Trigger) bereinigt wird,
kann das `User Data`-Verzeichnis eines konkreten Benutzers angesprochen
werden:

```powershell
$userData = 'C:\Users\Max.Mustermann\AppData\Local\Microsoft\Edge\User Data'

.\ExtensionCleanup.ps1 `
  -UserDataPath $userData `
  -AllProfiles `
  -LogPath "C:\ProgramData\EdgeCleanup\Max.Mustermann-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
```

### Variante C: Mehrere Benutzer in einer Logoff-/Cleanup-Routine

Beispiel für eine zentrale Routine (z. B. täglicher Task), die mehrere
lokale Benutzerprofile verarbeitet und pro Benutzer eine eigene Logdatei
schreibt. Innerhalb eines Benutzers werden alle Edge-Profile
(`Default`, `Profile 1`, …) automatisch über `-AllProfiles` abgedeckt:

```powershell
$logRoot = 'C:\ProgramData\EdgeCleanup\Logs'
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

$users = Get-ChildItem 'C:\Users' -Directory |
  Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } |
  ForEach-Object {
    [pscustomobject]@{
      User         = $_.Name
      UserDataPath = Join-Path $_.FullName 'AppData\Local\Microsoft\Edge\User Data'
    }
  }

foreach ($entry in $users) {
  if (-not (Test-Path -LiteralPath $entry.UserDataPath)) { continue }

  $log = Join-Path $logRoot "$($entry.User)-$timestamp.log"

  .\ExtensionCleanup.ps1 `
    -UserDataPath $entry.UserDataPath `
    -AllProfiles `
    -LogPath $log
}
```

### Hinweis für GPO/Scheduled Task

- GPO Logoff-Skript: Benutzerkonfiguration -> Windows-Einstellungen ->
  Skripts (Anmelden/Abmelden) -> Abmelden
- Scheduled Task: Trigger auf Logoff-Event oder zeitgesteuert außerhalb der
  Hauptnutzungszeiten
- Wichtig: Edge-Prozess des betreffenden Benutzers sollte beendet sein,
  damit die JSON-Dateien nicht gesperrt sind

## Backup und Wiederherstellung

Vor dem Schreiben erzeugt das Skript pro Datei ein Backup:

- `Preferences.bak.yyyyMMdd-HHmmss`
- `Secure Preferences.bak.yyyyMMdd-HHmmss`

### Restore (manuell)

1. Edge vollständig schließen
2. Gewünschte Backup-Datei über die aktuelle Datei kopieren
3. Edge neu starten

Beispiel:

```powershell
Copy-Item `
  -LiteralPath 'C:\...\Preferences.bak.20260630-115309' `
  -Destination 'C:\...\Preferences' `
  -Force
```

## Ausgabe des Skripts

Das Skript zeigt unter anderem:

- Anzahl installierter Extension-IDs
- gewählten Modus
- Backup-Pfad pro Datei
- Anzahl entfernter ID-Keys
- Anzahl entfernter ID-Stringwerte

## Logging

Zusätzlich zur Konsolenausgabe schreibt das Skript einen vollständigen
Lauf-Bericht in eine UTF-8-Logdatei (ohne BOM). Standardpfad:

```text
%TEMP%\EdgeExtensionCleanup_<yyyyMMdd-HHmmss>.log
```

Der Pfad kann über `-LogPath` überschrieben werden:

```powershell
.\ExtensionCleanup.ps1 -LogPath 'D:\Logs\EdgeCleanup\Cleanup.log'
```

Die Logdatei enthält:

- Header mit Benutzer, Computer, PowerShell-Version, Logpfad
- Anzahl installierter Extensions und gewählter Modus
- pro verarbeiteter Datei: Pfad, Backup-Pfad und Anzahl entfernter
  Schlüssel/Werte
- Warnungen (z. B. fehlende Datei) als `WARN`-Einträge
- Footer `=== Bereinigung abgeschlossen ===`

Nutzbar z. B. für zentrales Sammeln per Logoff-Skript: einfach `-LogPath`
auf einen freigegebenen Pfad mit eindeutigem Dateinamen pro Benutzer und
Session setzen.

## Wichtige Hinweise

- Das Skript entfernt Referenzen in den JSON-Dateien.
- Extension-Dateien auf Disk (Ordner unter `...\Extensions`) werden nicht
  gelöscht.
- Bei ungültigem JSON oder gesperrter Datei schlägt der Lauf fehl.

## Troubleshooting

### Edge läuft noch

Symptom: Schreibfehler auf `Preferences` oder `Secure Preferences`.

Lösung:

1. Edge komplett schließen (auch Hintergrundprozesse)
2. Skript erneut ausführen

### Datei nicht gefunden

Symptom: Warnung `Datei nicht gefunden, übersprungen`.

Lösung:

- Pfade prüfen (`-UserDataPath`, `-ProfileName` bzw. `-PreferencesPath` /
  `-SecurePreferencesPath`)
- Sicherstellen, dass das Profil existiert
- Bei `-AllProfiles`: prüfen, ob unter `-UserDataPath` überhaupt Profile
  mit `Preferences`-Datei vorhanden sind

### Unerwartetes Ergebnis

Lösung:

1. Backup zurückspielen
2. Mit Standardmodus statt Vollmodus starten
3. Ausgabe prüfen (entfernte Keys/Werte)

## Sicherheitshinweis

Nutze den Vollmodus nur bewusst. Er entfernt auch Referenzen aktiver
Extensions, wenn deren IDs im JSON gefunden werden.
