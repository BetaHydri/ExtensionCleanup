# ExtensionCleanup

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

- `PreferencesPath`:  
  `C:\Users\<User>\AppData\Local\Microsoft\Edge\User Data\Default\Preferences`
- `SecurePreferencesPath`:  
  `C:\Users\<User>\AppData\Local\Microsoft\Edge\User Data\Default\Secure Preferences`
- `ExtensionsPath`:  
  `C:\Users\<User>\AppData\Local\Microsoft\Edge\User Data\Default\Extensions`

## Parameter

- `-PreferencesPath <string>`  
  Pfad zur Datei `Preferences`.
- `-SecurePreferencesPath <string>`  
  Pfad zur Datei `Secure Preferences`.
- `-ExtensionsPath <string>`  
  Pfad zum Extensions-Ordner (wird für den Vergleich im Standardmodus
  genutzt).
- `-RemoveAllExtensionReferences`  
  Schaltet auf Vollmodus um.

## Beispiele

### 1) Standardlauf (empfohlen)

Entfernt nur verwaiste Verweise in `Preferences` und `Secure Preferences`:

```powershell
.\ExtensionCleanup.ps1
```

### 2) Vollbereinigung

Entfernt alle Extension-ID-Verweise in beiden Dateien:

```powershell
.\ExtensionCleanup.ps1 -RemoveAllExtensionReferences
```

### 3) Benutzerdefinierte Profilpfade

```powershell
.\ExtensionCleanup.ps1 `
  -PreferencesPath 'D:\Profiles\Edge\Default\Preferences' `
  -SecurePreferencesPath 'D:\Profiles\Edge\Default\Secure Preferences' `
  -ExtensionsPath 'D:\Profiles\Edge\Default\Extensions'
```

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

- Pfade prüfen (`-PreferencesPath`, `-SecurePreferencesPath`)
- Sicherstellen, dass das Profil existiert

### Unerwartetes Ergebnis

Lösung:

1. Backup zurückspielen
2. Mit Standardmodus statt Vollmodus starten
3. Ausgabe prüfen (entfernte Keys/Werte)

## Sicherheitshinweis

Nutze den Vollmodus nur bewusst. Er entfernt auch Referenzen aktiver
Extensions, wenn deren IDs im JSON gefunden werden.