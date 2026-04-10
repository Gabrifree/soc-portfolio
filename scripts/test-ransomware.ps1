<#
.SYNOPSIS
    Simulazione comportamento ransomware su File Server (laboratorio).

.DESCRIPTION
    Questo script simula il comportamento di un ransomware reale rinominando
    rapidamente i file .txt in una cartella di test, aggiungendo un'estensione
    fittizia ".stage.banalmente". Serve a validare le regole Wazuh di
    detection comportamentale (100041 → 100044 → 100045 → 100046).

    USO ESCLUSIVAMENTE IN AMBIENTE DI LABORATORIO CONTROLLATO.

.NOTES
    Author    : Portfolio SOC Lab
    Cartella  : C:\ProjectData\TEST_HACK\
    Fix       : test ransomware behavioral detection (catena 100041 → 100046)

.EXAMPLE
    PS> .\test-ransomware.ps1
#>

[CmdletBinding()]
param(
    [string]$TargetFolder = "C:\ProjectData\TEST_HACK",
    [int]$FileCount = 15,
    [int]$DelayMs = 100
)

# Verifica esistenza cartella
if (-not (Test-Path $TargetFolder)) {
    Write-Error "Cartella $TargetFolder non trovata. Esecuzione interrotta."
    exit 1
}

Write-Host "=== TEST RANSOMWARE SIMULATION ===" -ForegroundColor Yellow
Write-Host "Cartella target: $TargetFolder"
Write-Host "File da generare: $FileCount"
Write-Host ""

# Step 1: creazione massiva file (attiva regola 100041 → 100032)
Write-Host "[1/3] Creazione $FileCount file di test..." -ForegroundColor Cyan
1..$FileCount | ForEach-Object {
    $filePath = Join-Path $TargetFolder "test_file_$_.txt"
    "Test content $_" | Out-File -FilePath $filePath -Encoding UTF8
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "    File creati. Attendo 5s prima della rinomina..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# Step 2: rinomina massiva (attiva regola 100044 → 100045 → 100046)
Write-Host "[2/3] Rinomina massiva con estensione fittizia..." -ForegroundColor Cyan
Get-ChildItem -Path $TargetFolder -Filter "test_file_*.txt" | ForEach-Object {
    $newName = $_.Name + ".stage.banalmente"
    Rename-Item -Path $_.FullName -NewName $newName
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "    Rinomina completata." -ForegroundColor Gray
Start-Sleep -Seconds 3

# Step 3: cleanup (attiva regola 100043 → 100030)
Write-Host "[3/3] Cleanup - cancellazione massiva..." -ForegroundColor Cyan
Get-ChildItem -Path $TargetFolder -Filter "test_file_*" | ForEach-Object {
    Remove-Item -Path $_.FullName -Force
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host ""
Write-Host "=== SIMULAZIONE COMPLETATA ===" -ForegroundColor Green
Write-Host "Verifica gli alert sulla Wazuh Dashboard:"
Write-Host "  - Rule 100041 (creazione singola)         : atteso $FileCount alert"
Write-Host "  - Rule 100032 (creazione massiva)         : atteso 1+ alert"
Write-Host "  - Rule 100044 (rinomina rapida)           : atteso $FileCount alert"
Write-Host "  - Rule 100045 (pattern ransomware)        : atteso 1+ alert"
Write-Host "  - Rule 100046 (ATTACCO DI MASSA)          : atteso 1 alert Lv15"
Write-Host "  - Rule 100043 (cancellazione singola)     : atteso $FileCount alert"
Write-Host "  - Rule 100030 (cancellazione massiva)     : atteso 1+ alert"
