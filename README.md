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
  (das Skript prüft dies seit Version 1.4 automatisch — siehe
  [Robustheit gegen laufenden Edge](#robustheit-gegen-laufenden-edge))

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
- `-Force`  
  Übergeht die Pre-Flight-Prüfung „Edge läuft in der aktuellen Session".
  Ist Edge bereits offen, beendet das Skript zuerst alle `msedge.exe`-
  Prozesse **der aktuellen Benutzersession** (`Get-Process msedge` gefiltert
  nach `SessionId`) und führt anschließend die Bereinigung aus. Ohne
  `-Force` beendet sich das Skript mit Exit 0 und einer `WARN`-Meldung,
  damit Logoff- und Maintenance-Pipelines (z. B. Ivanti) nicht mit Fehler
  17 / `IOException 0x80070020` brechen. `-Force` ist in jedem
  ParameterSet zulässig (siehe [Parametersätze](#parametersätze)).
- `-LogPath <string>`  
  Pfad zur Logdatei für diesen Lauf. Standardwert:
  `%TEMP%\EdgeExtensionCleanup_<yyyyMMdd-HHmmss>.log`.
  Die Datei wird bei jedem Lauf neu erstellt (kein Append).

## Parametersätze

Die Parameter sind in drei sich gegenseitig ausschließende
Parametersätze (ParameterSets) gruppiert. Pro Aufruf darf nur **einer**
davon verwendet werden; das Mischen erzwingt PowerShell hostseitig mit
der Fehlermeldung `AmbiguousParameterSet`.

| ParameterSet | Pflichtparameter           | Optional zusätzlich nutzbar                            |
| ------------ | -------------------------- | ------------------------------------------------------ |
| `ByProfile`  | *(keiner; Standardset)*    | `-UserDataPath`, `-ProfileName`                        |
| `AllProfiles`| `-AllProfiles`             | `-UserDataPath`                                        |
| `Legacy`     | `-PreferencesPath`         | `-SecurePreferencesPath`, `-ExtensionsPath`            |

In jedem ParameterSet sind zusätzlich `-RemoveAllExtensionReferences`,
`-Force` und `-LogPath` zulässig.

Der aktive ParameterSet wird im Lauf-Log in einer eigenen Zeile
festgehalten, z. B.:

```text
ParamSet   : AllProfiles
```

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

### 8) Ungültige Parameterkombinationen

Folgende Aufrufe schlägt PowerShell direkt mit `AmbiguousParameterSet`
ab, weil sie Parameter aus verschiedenen ParameterSets mischen:

```powershell
# Mischt 'ByProfile' (-ProfileName) und 'Legacy' (-PreferencesPath)
.\ExtensionCleanup.ps1 -ProfileName 'Default' -PreferencesPath 'C:\X\Preferences'

# Mischt 'AllProfiles' und 'Legacy'
.\ExtensionCleanup.ps1 -AllProfiles -PreferencesPath 'C:\X\Preferences'

# Mischt 'ByProfile' (-ProfileName) und 'AllProfiles' (-AllProfiles)
.\ExtensionCleanup.ps1 -ProfileName 'Default' -AllProfiles
```

### 9) Robust gegen laufenden Edge (Pre-Flight)

Ab Version 1.4 prüft das Skript vor jeder Bereinigung, ob in der
**aktuellen Benutzersession** ein `msedge.exe`-Prozess läuft. Die
Prüfung verwendet `Get-Process msedge` und filtert auf
`SessionId == (Get-Process -Id $PID).SessionId`. Edge-Prozesse anderer
Benutzer auf demselben Rechner werden bewusst ignoriert.

Standardverhalten (ohne `-Force`) — bricht **sauber** ab, statt Edge
in laufende Dateien schreiben zu lassen:

```powershell
.\ExtensionCleanup.ps1
# [WARN] msedge.exe läuft in der aktuellen Session. Cleanup wird übersprungen (Exit 0).
# [INFO] Hinweis: Edge schließen und Skript erneut starten, oder -Force verwenden.
# [INFO] === Bereinigung abgeschlossen ===
# Exit-Code: 0
```

Mit `-Force` — beendet zuerst alle `msedge.exe`-Prozesse der eigenen
Session und bereinigt anschließend:

```powershell
.\ExtensionCleanup.ps1 -Force
# [WARN] msedge.exe läuft, -Force gesetzt — beende msedge.exe in Session 1.
# [WARN] Beendete msedge-Prozesse: 7
# === Profil: Default ===
# ...
# [INFO] === Bereinigung abgeschlossen ===
```

Im Lauf-Log-Header taucht die `-Force`-Wahl explizit auf:

```text
Force      : True
```

Der Pre-Flight gilt **nicht** im `Legacy`-ParameterSet
(`-PreferencesPath`), damit explizite Pfade — typischerweise auf
offline gesicherte Profile — auch dann verarbeitet werden, wenn der
Benutzer parallel mit einem anderen Edge-Profil arbeitet.

### 10) Per-Datei-Resilienz bei gesperrten Dateien

Wird eine einzelne Datei (z. B. `Secure Preferences`) während der
Bereinigung gesperrt — etwa durch einen kurz nach dem Pre-Flight wieder
gestarteten Edge-Hintergrundprozess oder durch ein AV-/Backup-Tool —
überspringt das Skript diese eine Datei, **verarbeitet die anderen
Dateien des Profils weiter** und beendet sich am Ende trotzdem mit
Exit-Code 0:

```text
=== Profil: Default ===
[INFO] Datei: ...\Default\Preferences
[INFO] Entfernte Keys: 1, entfernte Stringwerte: 0
[WARN] Datei gesperrt, übersprungen: ...\Default\Secure Preferences
        (Der Prozess kann nicht auf die Datei zugreifen,
         da sie von einem anderen Prozess verwendet wird.)
[WARN] Hinweis: 1 Datei(en) wurden ausgelassen (gesperrt oder fehlend).
       Lauf endet trotzdem mit Exit-Code 0.
[INFO] === Bereinigung abgeschlossen ===
```

Damit bleibt das Skript für unbeaufsichtigte Maintenance-Pipelines
(Ivanti, ConfigMgr, Scheduled Tasks, Logoff-Skripte) zuverlässig:

- `IOException` / `UnauthorizedAccessException` einer Einzeldatei
  führen nicht mehr zum harten Abbruch des Gesamtlaufs.
- Der Lauf ist deterministisch idempotent: beim nächsten Lauf wird die
  zuvor gesperrte Datei erneut versucht.

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

Symptom: Schreibfehler auf `Preferences` oder `Secure Preferences`,
bzw. `IOException 0x80070020`.

Lösung (ab Version 1.4 automatisch abgefangen):

- Pre-Flight-Gate aktiv: Skript bricht mit `WARN` und Exit 0 ab, wenn
  `msedge.exe` in der aktuellen Session läuft → Edge schließen und
  erneut starten.
- Alternativ `-Force` setzen — das Skript beendet `msedge.exe` der
  eigenen Session und bereinigt anschließend (siehe
  [Beispiel 9](#9-robust-gegen-laufenden-edge-pre-flight)).
- Sperrt ein Hintergrundprozess (AV, Backup) eine **einzelne** Datei
  während des Laufs, wird nur diese Datei übersprungen — der Lauf
  endet trotzdem mit Exit 0 (siehe
  [Beispiel 10](#10-per-datei-resilienz-bei-gesperrten-dateien)).

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
