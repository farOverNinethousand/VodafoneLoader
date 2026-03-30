# vfloader-install.ps1

$targetDir = "$env:USERPROFILE\Downloads\vfloader"
$scriptUrl = "https://raw.githubusercontent.com/farOverNinethousand/VodafoneLoader/main/vfloader.ps1"
$scriptPath = "$targetDir\vfloader.ps1"
$githubUrl = "https://github.com/farOverNinethousand/VodafoneLoader"

# Zielordner erstellen falls nicht vorhanden
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

# Skript herunterladen
Write-Host "Lade vfloader herunter..."
try {
    Invoke-RestMethod -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop
} catch {
    Write-Host "FEHLER: Download fehlgeschlagen." -ForegroundColor Red
    Write-Host "Bitte lade das Skript manuell herunter: $githubUrl" -ForegroundColor Yellow
    exit 1
}

# Prüfen ob Datei existiert und nicht leer ist
if (-not (Test-Path $scriptPath) -or (Get-Item $scriptPath).Length -eq 0) {
    Write-Host "FEHLER: Heruntergeladene Datei ist leer oder fehlt." -ForegroundColor Red
    Write-Host "Bitte lade das Skript manuell herunter: $githubUrl" -ForegroundColor Yellow
    exit 1
}

# Prüfen ob Datei gültigen PowerShell-Inhalt hat
$content = Get-Content $scriptPath -Raw
if ($content -notmatch '(?i)#.*vfloader|Vodafone') {
    Write-Host "FEHLER: Unerwarteter Dateiinhalt - dies ist möglicherweise nicht das richtige Skript." -ForegroundColor Red
    Write-Host "Bitte lade das Skript manuell herunter: $githubUrl" -ForegroundColor Yellow
    Remove-Item $scriptPath -Force
    exit 1
}

# Ausgabe: Speicherort
Write-Host "Gespeichert unter: $scriptPath" -ForegroundColor Green

# Explorer öffnen mit markierter Datei
explorer.exe /select, $scriptPath

# Skript starten
Write-Host "Starte vfloader..."
& $scriptPath