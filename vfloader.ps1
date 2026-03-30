# ============================================================
# Konfiguration
# ============================================================

# Ob die results.txt nach erfolgreichem Abschluss automatisch geoeffnet werden soll.
$OPEN_RESULTS_ON_SUCCESS = $true

# Ob die results.txt nach erfolgreichem Abschluss in die Zwischenablage kopiert werden soll.
# Praktisch um Ergebnisse schnell weiterzuteilen, kann bei Bedarf deaktiviert werden.
$COPY_RESULTS_TO_CLIPBOARD = $true

# Maximale Wartezeit zwischen zwei Einloesungen in Sekunden.
# Die tatsaechliche Wartezeit wird zufaellig zwischen 1 und diesem Wert gewaehlt.
$MAX_WAIT_SECONDS_BETWEEN_CODES = 10

# Standardwert fuer ETA beim ersten Durchlauf (Sekunden)
$DEFAULT_ETA_SECS = 5

# Pausenpuffer der zur ETA addiert wird um die Wartezeit zwischen Codes einzurechnen
$ETA_PAUSE_BUFFER_SECS = 5

$TIMEOUT_SECS = 60
$RESULTS_FILE = ".\results.txt"
$REMAINING_FILE = ".\remaining_codes.txt"

# ============================================================
# Debug-Konfiguration
# ============================================================

# Debug-Flag: Aktiviert zusaetzliche Konsolenausgaben und speichert screen_debug.xml bei jedem UI-Dump
$DEBUG_ENABLED = $false

# Redeem-Command-Debug-Flag: Ersetzt den echten Einloese-Befehl durch eine harmlose Guthabenabfrage.
# WICHTIG: Auf $false setzen fuer echten Betrieb!
# Hintergrund: Zu viele fehlgeschlagene Einloeseversuche koennen eine Vodafone-Sperre ausloesen.
$DEBUG_REDEEM_COMMAND = $false

# Redeem-Codes-Debug-Flag: Verwendet hardcodierte Testcodes statt Benutzereingabe.
# WICHTIG: Auf $false setzen fuer echten Betrieb!
$DEBUG_REDEEM_CODES = $false

# Testcodes - nur verwendet wenn DEBUG_REDEEM_CODES aktiv ist
# Vodafone Codes: beginnen immer mit 108, immer 15-stellig
$DEBUG_CODES = @("108000000000001", "108000000000002", "108000000000003")

# ============================================================
# Hilfsfunktionen
# ============================================================
function Write-Poll {
    param($message)
    Write-Host "`r  $message" -NoNewline
}

function Write-PollDone {
    Write-Host ""
}

function Write-Success {
    param($message)
    Write-Host $message -ForegroundColor Green
}

function Write-Fail {
    param($message)
    Write-Host $message -ForegroundColor Red
}

function Write-Warn {
    param($message)
    Write-Host $message -ForegroundColor Yellow
}

function Write-Info {
    param($message)
    Write-Host $message -ForegroundColor DarkYellow
}

function Exit-WithKey {
    param($message = "Druecke eine beliebige Taste zum Beenden...")
    Write-Host ""
    Write-Host $message
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

function Is-ValidCode {
    param($code)
    return $code -match "^108\d{12}$"
}

function Is-OnHomescreen {
    # Prueft ob das Geraet sich aktuell auf dem Homescreen befindet
    # indem der aktuelle Fensterfokus auf "launcher" geprueft wird
    $focus = & $ADB shell dumpsys window windows | Select-String "mCurrentFocus"
    return ($focus -match "launcher")
}

function Ensure-Homescreen {
    # Navigiert zum Homescreen, aber nur wenn nicht bereits dort
    # um unnoetigen ADB-Traffic und Animationen zu vermeiden
    if (-not (Is-OnHomescreen)) {
        if ($DEBUG_ENABLED) { Write-Host "Navigiere zum Homescreen..." }
        & $ADB shell input keyevent KEYCODE_HOME
        Start-Sleep -Seconds 1
    } else {
        if ($DEBUG_ENABLED) { Write-Host "Bereits auf Homescreen - kein Navigieren noetig." }
    }
}

function Wait-DeviceReady {
    $attempt = 0
    while ($true) {
        $rawList = @(& $ADB devices | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" })
        $authorizedDevices = @($rawList | Where-Object { $_ -match "\bdevice$" })
        if ($authorizedDevices.Count -gt 0) {
            if ($attempt -gt 0) { Write-PollDone }
            return $authorizedDevices
        }
        $attempt++
        if ($rawList.Count -eq 0) {
            Write-Poll "Kein Geraet verbunden - bitte Android-Geraet per USB anschliessen und USB-Debugging aktivieren... (Versuch $attempt)"
        } else {
            Write-Poll "Geraet gefunden aber nicht autorisiert - bitte USB-Debugging auf dem Geraet bestaetigen... (Versuch $attempt)"
        }
        Start-Sleep -Seconds 3
    }
}

function Wait-DeviceUnlocked {
    $wasLocked = $false
    $lockAttempt = 0
    while ($true) {
        $locked = (& $ADB shell dumpsys window | Select-String "mDreamingLockscreen") -match "true"
        if (-not $locked) {
            if ($wasLocked) {
                Write-PollDone
                Write-Host "Geraet entsperrt - warte kurz..."
                Start-Sleep -Seconds 1
                Ensure-Homescreen
            }
            break
        }
        $wasLocked = $true
        $lockAttempt++
        Write-Poll "Geraet gesperrt - bitte entsperren... (Versuch $lockAttempt)"
        Start-Sleep -Seconds 2
    }
}

# ============================================================
# Schreibrechte pruefen
# ============================================================
$currentUser = $env:USERNAME
$suggestedPath = "C:\Users\$currentUser\Downloads\vfloader"

$writeTestFile = ".\writetest.txt"
if (Test-Path $writeTestFile) {
    Write-Warn "HINWEIS: writetest.txt existierte bereits und wird geloescht."
    Remove-Item $writeTestFile -Force
}

$writeOk = $false
try {
    "test" | Out-File $writeTestFile -ErrorAction Stop
    if (Test-Path $writeTestFile) {
        Remove-Item $writeTestFile -Force
        $writeOk = $true
    }
} catch {}

if (-not $writeOk) {
    Write-Fail "FEHLER: Keine Schreibrechte im aktuellen Verzeichnis."
    Write-Host ""
    Write-Host "Moegliche Loesungen:"
    Write-Host "  - Script als Administrator starten (Rechtsklick -> Als Administrator ausfuehren)"
    Write-Host "  - Script in einen Ordner verschieben, auf den du Schreibrechte hast,"
    Write-Host "    z.B.: $suggestedPath"
    Exit-WithKey
}
if ($DEBUG_ENABLED) { Write-Host "Schreibrechte OK." }

# ============================================================
# Aufraumen
# ============================================================
if (Test-Path ".\screen.xml") {
    Remove-Item ".\screen.xml" -Force
    Write-Host "Alte screen.xml geloescht."
}

# ============================================================
# Pruefen ob results.txt bereits existiert und nicht-leer ist
# (wird am Ende in der Ausgabe erwaehnt)
# ============================================================
$resultsExistedBefore = (Test-Path $RESULTS_FILE) -and ((Get-Item $RESULTS_FILE).Length -gt 0)

# ============================================================
# ADB verfuegbar?
# ============================================================
$ADB = $null
if (Get-Command "adb" -ErrorAction SilentlyContinue) {
    $ADB = "adb"
} elseif (Test-Path ".\adb.exe") {
    $ADB = ".\adb.exe"
} elseif (Test-Path ".\platform-tools\adb.exe") {
    $ADB = ".\platform-tools\adb.exe"
}

if (-not $ADB) {
    Write-Fail "FEHLER: ADB wurde nicht gefunden."
    Write-Host ""
    Write-Host "ADB wird benoetigt um mit dem Android-Geraet zu kommunizieren."
    Write-Host ""
    Write-Host "Anleitungen zur Einrichtung von ADB auf dem Handy (muss manuell erfolgen):"
    Write-Host "  EN: https://www.xda-developers.com/install-adb-windows-macos-linux/"
    Write-Host "  DE: https://support.isafe-mobile.com/de/support/solutions/articles/77000569929-wie-installiere-ich-adb-auf-meinem-pc-"
    Write-Host ""
    Write-Host "  (1) ADB automatisch herunterladen und verwenden"
    Write-Host "      Hinweis: ADB muss auf deinem Handy weiterhin manuell eingerichtet werden"
    Write-Host "      (siehe Anleitung oben). Die englische Anleitung wird im Browser geoeffnet."
    Write-Host "  (2) Hilfeartikel im Browser oeffnen und Script beenden"
    Write-Host "  (beliebige Taste) Script beenden"
    Write-Host ""

    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    if ($key.Character -eq "1") {
        Start-Process "https://www.xda-developers.com/install-adb-windows-macos-linux/"

        Write-Host ""
        Write-Host "Lade ADB herunter..."

        $zipUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
        $zipPath = ".\platform-tools-latest-windows.zip"

        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop
            Write-Host "Download abgeschlossen. Entpacke..."
            Expand-Archive -Path $zipPath -DestinationPath "." -Force -ErrorAction Stop
            Remove-Item $zipPath -Force

            if (Test-Path ".\platform-tools\adb.exe") {
                $ADB = ".\platform-tools\adb.exe"
                Write-Success "ADB erfolgreich heruntergeladen: $ADB"
            } else {
                Write-Fail "FEHLER: ADB konnte nach dem Entpacken nicht gefunden werden."
                Exit-WithKey
            }
        } catch {
            Write-Fail "FEHLER beim Herunterladen oder Entpacken: $_"
            Exit-WithKey
        }
    } elseif ($key.Character -eq "2") {
        Start-Process "https://www.xda-developers.com/install-adb-windows-macos-linux/"
        exit
    } else {
        exit
    }
}

# ============================================================
# Geraete pruefen
# ============================================================
$authorizedDevices = Wait-DeviceReady
Write-Success "Autorisierte(s) Geraet(e) gefunden:"
$authorizedDevices | ForEach-Object {
    $id = ($_ -split "\t")[0].Trim()
    Write-Host "  - $id"
}
# @() erzwingt Array-Behandlung damit [0] das erste Element liefert und nicht das erste Zeichen
$firstDevice = @($authorizedDevices)[0]
$deviceId = ($firstDevice -split "\t")[0].Trim()
Write-Host "Verwende Geraet: $deviceId"

# ============================================================
# Codes bestimmen
# ============================================================
$CODES = @()

if ($DEBUG_REDEEM_CODES) {
    Write-Host ""
    Write-Warn "*** REDEEM CODES DEBUG AKTIV - Es werden hardcodierte Testcodes verwendet! ***"
    Write-Host ""
    $CODES = $DEBUG_CODES
} else {
    $remainingFromFile = @()
    if (Test-Path $REMAINING_FILE) {
        $remainingFromFile = @(Get-Content $REMAINING_FILE | Where-Object { Is-ValidCode $_.Trim() })

        if ($remainingFromFile.Count -eq 0) {
            Write-Host "remaining_codes.txt enthielt keine gueltigen Codes und wird geloescht."
            Remove-Item $REMAINING_FILE -Force
        }
    }

    if ($remainingFromFile.Count -gt 0) {
        Write-Host ""
        Write-Warn "Es wurden $($remainingFromFile.Count) verbleibende Code(s) der letzten Einloesung in remaining_codes.txt gefunden:"
        $remainingFromFile | ForEach-Object { Write-Host "  - $_" }
        Write-Host ""
        Write-Host "  (1) Mit letztem Einloesesvorgang fortfahren"
        Write-Host "  (2) Neue Codes eingeben"
        Write-Host "  (3) Script beenden"
        Write-Host ""

        while ($true) {
            $choice = Read-Host "  Auswahl (1, 2 oder 3)"
            if ($choice -eq "1") {
                $CODES = $remainingFromFile
                Write-Host "Fahre mit $($CODES.Count) verbleibenden Code(s) fort."
                break
            } elseif ($choice -eq "2") {
                break
            } elseif ($choice -eq "3") {
                Write-Host "Script wird beendet."
                exit
            } else {
                Write-Warn "  Bitte 1, 2 oder 3 eingeben."
            }
        }
    }

    if ($CODES.Count -eq 0) {
        Write-Host ""
        Write-Host "Bitte Vodafone Codes eingeben (15-stellig, beginnen mit 108)."
        Write-Host "Codes zeilengetrennt einfuegen und dann 1-2x Enter druecken um die Einloesung zu starten."
        Write-Host ""

        while ($true) {
            $inputCodes = @()
            $inputLines = @()

            while ($true) {
                $line = Read-Host "  Code(s) eingeben"
                if ($line.Trim() -eq "") { break }
                $inputLines += $line
            }

            foreach ($inputLine in $inputLines) {
                $tokens = $inputLine -split "\s+"
                foreach ($token in $tokens) {
                    $token = $token.Trim()
                    if ($token -eq "") { continue }
                    if (Is-ValidCode $token) {
                        $inputCodes += $token
                        Write-Success "  OK: $token hinzugefuegt."
                    } else {
                        Write-Warn "  Ignoriert (ungueltig): $token"
                    }
                }
            }

            if ($inputCodes.Count -eq 0) {
                Write-Warn "  Keine gueltigen Codes gefunden. Bitte mindestens einen gueltigen Code eingeben."
                Write-Host "  (Codes muessen 15-stellig sein und mit 108 beginnen)"
            } else {
                $CODES = $inputCodes
                break
            }
        }
    }

    Write-Host ""
    Write-Host "$($CODES.Count) Code(s) werden eingeloest."
}

# ============================================================
# Alle Codes vorab in REMAINING_FILE schreiben
# ============================================================
$CODES | Out-File $REMAINING_FILE -Encoding UTF8
if ($DEBUG_ENABLED) { Write-Host "Verbleibende Codes in remaining_codes.txt gespeichert." }

# ============================================================
# Geraet entsperrt? (nach Codeeingabe, da sich Geraet zwischenzeitlich sperren kann)
# ============================================================
Wait-DeviceUnlocked

# ============================================================
# Zum Homescreen navigieren vor der Einloeseschleife
# ============================================================
Ensure-Homescreen

# ============================================================
# Hauptfunktionen
# ============================================================
function Wait-CallEnd {
    $callState = (& $ADB shell dumpsys telephony.registry | Select-String "mCallState" | Select-Object -First 1) -replace ".*mCallState=(\d+).*", '$1'
    if ($callState -eq "2") {
        Write-Host "  Aktiver Anruf erkannt - warte bis der Benutzer auflegt..."
        $attempt = 0
        while ($true) {
            $callState = (& $ADB shell dumpsys telephony.registry | Select-String "mCallState" | Select-Object -First 1) -replace ".*mCallState=(\d+).*", '$1'
            if ($callState -ne "2") {
                Write-PollDone
                Write-Host "  Anruf beendet - fahre fort"
                break
            }
            $attempt++
            Write-Poll "  Warte auf Anrufende... (Versuch $attempt)"
            Start-Sleep -Milliseconds 500
        }
    } elseif ($callState -eq "1") {
        Write-Host "  Eingehender Anruf erkannt - wird abgewiesen"
        & $ADB shell input keyevent KEYCODE_ENDCALL
    }
}

function Keep-ScreenAwake {
    & $ADB shell input tap 1 1
}

function Parse-Result {
    # Wertet den Antworttext des USSD-Dialogs aus und gibt einen
    # strukturierten Status zurueck:
    #   "OK:<betrag>"        -> Code erfolgreich eingeloest, Betrag als Dezimalzahl
    #   "BEREITS_EINGELOEST" -> Code wurde schon verwendet
    #   "UNBEKANNT"          -> Antwort konnte keinem bekannten Status zugeordnet werden
    param($text)
    if ($text -match "(\d+[.,]\d{2})\s*EUR") {
        $amount = $matches[1] -replace ",", "."
        return "OK:$amount"
    } elseif ($text -match "schon verwendet|bereits.*verwendet|already used") {
        return "BEREITS_EINGELOEST"
    } else {
        return "UNBEKANNT"
    }
}

function Extract-Message {
    # Extrahiert den sichtbaren Antworttext aus dem UI-Dump XML.
    # Sucht nach dem TextView mit resource-id "android:id/message",
    # das ist das Element in dem der USSD-Antworttext vom System angezeigt wird.
    # Gibt den text-Attributwert zurueck, oder einen leeren String wenn nichts gefunden wurde.
    param($xml)
    $match = [regex]::Match($xml, 'resource-id="android:id/message"[^>]*text="([^"]+)"')
    if (-not $match.Success) {
        # Attributreihenfolge kann je nach Android-Version variieren - beide Reihenfolgen pruefen
        $match = [regex]::Match($xml, 'text="([^"]+)"[^>]*resource-id="android:id/message"')
    }
    return $match.Groups[1].Value
}

function Get-UIXml {
    # Holt einen frischen UI-Dump vom Geraet und gibt ihn als String zurueck.
    # Gibt einen leeren String zurueck wenn der Dump fehlschlaegt oder ungueltig ist.
    #
    # Ablauf:
    #   1. Alte XML auf dem Geraet loeschen (verhindert dass veralteter Stand gelesen wird)
    #   2. uiautomator dump auf dem Geraet ausloesen
    #   3. Warten bis die Datei vollstaendig geschrieben ist (uiautomator kehrt zu frueh zurueck)
    #   4. Datei per adb pull lokal ziehen
    #   5. Validitaet pruefen (muss <hierarchy> enthalten)
    #   6. Im Debug-Modus als screen_debug.xml speichern

    & $ADB shell rm -f /sdcard/screen.xml 2>$null
    & $ADB shell uiautomator dump /sdcard/screen.xml 2>$null

    $waited = 0
    while ($waited -lt 3000) {
        $size = & $ADB shell stat -c "%s" /sdcard/screen.xml 2>$null
        if ($size -and [int]$size -gt 0) { break }
        Start-Sleep -Milliseconds 200
        $waited += 200
    }

    if (Test-Path ".\screen.xml") { Remove-Item ".\screen.xml" -Force }
    & $ADB pull /sdcard/screen.xml ".\screen.xml" 2>$null

    if (-not (Test-Path ".\screen.xml")) { return "" }

    $xml = Get-Content ".\screen.xml" -Raw -Encoding UTF8

    if ($xml -notmatch "<hierarchy") { return "" }

    if ($DEBUG_ENABLED) {
        Copy-Item ".\screen.xml" -Destination ".\screen_debug.xml" -Force
    }

    return $xml
}

function Is-UssdExecuting {
    param($xml)
    $hasExecutingText = $xml -match "USSD-Code wird ausgef"
    $hasOkButton = $xml -match 'resource-id="android:id/button1"'
    return ($hasExecutingText -or -not $hasOkButton)
}

function Save-UnknownError {
    if (Test-Path ".\screen.xml") {
        Copy-Item ".\screen.xml" -Destination ".\screen_unknown_error.xml" -Force
        Write-Host "  screen_unknown_error.xml gespeichert."
    }
}

function Close-DialogIfOpen {
    if ($DEBUG_ENABLED) { Write-Host "  [DEBUG] Sende ENTER (1. Versuch Dialog schliessen)" }
    & $ADB shell input keyevent KEYCODE_ENTER
    Start-Sleep -Milliseconds 500

    $xml = Get-UIXml
    if ($xml -match "android:id/message") {
        if ($DEBUG_ENABLED) { Write-Host "  [DEBUG] Dialog noch offen - sende ENTER (2. Versuch)" }
        & $ADB shell input keyevent KEYCODE_ENTER
        Start-Sleep -Milliseconds 300
    }
}

# ============================================================
# results.txt erst hier erstellen - so spaet wie moeglich, damit kein
# leerer Muell entsteht falls das Script vorher abbricht
# ============================================================
if (-not (Test-Path $RESULTS_FILE)) {
    New-Item -ItemType File -Path $RESULTS_FILE | Out-Null
    Write-Host "results.txt neu erstellt."
} else {
    Write-Host "results.txt gefunden - Ergebnisse werden angehaengt."
}

# ============================================================
# Hauptschleife
# ============================================================
$totalCodes = $CODES.Count
$totalCollected = 0.0
$lastDurationSecs = $DEFAULT_ETA_SECS

for ($i = 0; $i -lt $totalCodes; $i++) {
    $CODE = $CODES[$i]

    $authorizedDevices = Wait-DeviceReady
    Wait-DeviceUnlocked

    $remaining = $totalCodes - $i
    $eta = [math]::Round(($lastDurationSecs + $ETA_PAUSE_BUFFER_SECS) * $remaining)
    $collectedDisplay = "{0:F2}" -f $totalCollected
    Write-Host ""
    Write-Host "=== Code $($i + 1)/$totalCodes | ETA ~$($eta)s | Bisher: $collectedDisplay EUR ==="
    Write-Host "    Code: $CODE"

    $redeemStart = Get-Date

    if ($DEBUG_REDEEM_COMMAND) {
        if ($DEBUG_ENABLED) {
            & $ADB shell am start -a android.intent.action.CALL -d "tel:*100*%23"
        } else {
            & $ADB shell am start -a android.intent.action.CALL -d "tel:*100*%23" | Out-Null
        }
    } else {
        if ($DEBUG_ENABLED) {
            & $ADB shell am start -a android.intent.action.CALL -d "tel:*100*${CODE}%23"
        } else {
            & $ADB shell am start -a android.intent.action.CALL -d "tel:*100*${CODE}%23" | Out-Null
        }
    }

    $startTime = Get-Date
    $xml = ""

    while ($true) {
        Wait-CallEnd
        Keep-ScreenAwake

        $xml = Get-UIXml
        $elapsed = (Get-Date) - $startTime
        $remainingSecs = [math]::Round($TIMEOUT_SECS - $elapsed.TotalSeconds)

        if ($xml -match "android:id/message") {
            if (-not (Is-UssdExecuting -xml $xml)) {
                Write-PollDone
                break
            }
            Write-Poll "  USSD wird ausgefuehrt... (noch max $remainingSecs s)"
        } else {
            Write-Poll "  Warte auf Dialog... (noch max $remainingSecs s)"
        }

        if ($elapsed.TotalSeconds -ge $TIMEOUT_SECS) {
            Write-PollDone
            Write-Fail "  FEHLER: Kein Dialogfenster-Feedback gefunden innerhalb von $TIMEOUT_SECS Sekunden."
            Write-Host "  Bisherige Ergebnisse in: $RESULTS_FILE"
            "$CODE TIMEOUT" | Add-Content $RESULTS_FILE
            Exit-WithKey
        }

        Start-Sleep -Milliseconds 500
    }

    $lastDurationSecs = [math]::Round(((Get-Date) - $redeemStart).TotalSeconds)
    if ($DEBUG_ENABLED) { Write-Host "  [DEBUG] Vorgang dauerte $lastDurationSecs s (wird fuer naechste ETA verwendet)" }

    $msg = Extract-Message -xml $xml
    Write-Host "  Antwort: $msg"

    $result = Parse-Result -text $msg

    if ($result -like "OK:*") {
        $amount = [double]($result -replace "OK:", "")
        $totalCollected += $amount
        $amountDisplay = "{0:F2}" -f $amount
        Write-Success "  Erfolgreich: $amountDisplay EUR"
        "$CODE $amountDisplay EUR" | Add-Content $RESULTS_FILE
    } elseif ($result -eq "BEREITS_EINGELOEST") {
        Write-Warn "  Code bereits eingeloest"
        "$CODE BEREITS_EINGELOEST" | Add-Content $RESULTS_FILE
    } else {
        Save-UnknownError
        $errorMsg = Extract-Message -xml $xml
        if ($errorMsg -ne "") {
            Write-Warn "  Fehler: $errorMsg"
            "$CODE FEHLER: $errorMsg" | Add-Content $RESULTS_FILE
        } else {
            Write-Fail "  Unbekannte Antwort && Fehlermeldung konnte nicht geparsed werden - Abbruch!"
            Write-Host "  Bisherige Ergebnisse in: $RESULTS_FILE"
            "$CODE UNBEKANNT" | Add-Content $RESULTS_FILE
            Exit-WithKey
        }
    }

    if ($i -lt ($totalCodes - 1)) {
        $CODES[($i + 1)..($totalCodes - 1)] | Out-File $REMAINING_FILE -Encoding UTF8
    }

    Close-DialogIfOpen

    if (Test-Path ".\screen.xml") { Remove-Item ".\screen.xml" -Force }
    & $ADB shell rm -f /sdcard/screen.xml 2>$null

    if ($i -lt ($totalCodes - 1)) {
        $wait = Get-Random -Minimum 1 -Maximum ($MAX_WAIT_SECONDS_BETWEEN_CODES + 1)
        $waitCount = 0
        while ($waitCount -lt $wait) {
            Write-Poll "  Warte vor naechstem Code... (noch $($wait - $waitCount) s)"
            Start-Sleep -Seconds 1
            $waitCount++
        }
        Write-PollDone
    }
}

# Alle Codes verarbeitet - remaining_codes.txt loeschen
if (Test-Path $REMAINING_FILE) {
    Remove-Item $REMAINING_FILE -Force
}

# Clear-Host nur wenn DEBUG_ENABLED false ist.
# Im Debug-Modus soll die vollstaendige Ausgabe sichtbar bleiben
# um Fehler und Zwischenschritte nachvollziehen zu koennen.
if (-not $DEBUG_ENABLED) {
    Clear-Host
}

$totalDisplay = "{0:F2}" -f $totalCollected
$results = Get-Content $RESULTS_FILE
Write-Success "=== Alle $totalCodes Codes verarbeitet | Gesamt eingeloest: $totalDisplay EUR ==="
Write-Host ""

# Hinweis falls die Datei bereits vorher existierte und Inhalte dazugeschrieben wurden
if ($resultsExistedBefore) {
    Write-Info "Hinweis: Die results.txt existierte bereits vor diesem Durchlauf."
    Write-Info "Die neuen Ergebnisse wurden an den bestehenden Inhalt angehaengt."
    Write-Host ""
}

Write-Success "Inhalt der results.txt ($RESULTS_FILE):"
Write-Host ""
$results | ForEach-Object { Write-Success $_ }

if ($COPY_RESULTS_TO_CLIPBOARD) {
    $results | Set-Clipboard
    Write-Host ""
    Write-Success "Inhalt der results.txt wurde in die Zwischenablage kopiert."
}

# results.txt automatisch oeffnen wenn konfiguriert
$resolvedResultsPath = (Resolve-Path $RESULTS_FILE).Path
if ($OPEN_RESULTS_ON_SUCCESS) {
    Start-Process $resolvedResultsPath
}

# ============================================================
# Abschlussmenue
# ============================================================
Write-Host ""
Write-Host "  (1) Ordner mit results.txt oeffnen und Script beenden"
Write-Host "  (2) Script beenden"
Write-Host "  (ENTER oder beliebige Taste) Script beenden"
Write-Host ""

$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
if ($key.Character -eq "1") {
    Start-Process explorer.exe -ArgumentList "/select,`"$resolvedResultsPath`""
}