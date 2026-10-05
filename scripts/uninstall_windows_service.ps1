# OmniBridge POS - Desinstalador de Servicio de Windows (NSSM)
# Requiere ejecucion en PowerShell como Administrador

param(
    [string]$InstallDir = "C:\PosAgent"
)

$ErrorActionPreference = "Stop"

Write-Host "===========================================================" -ForegroundColor Yellow
Write-Host "  OmniBridge POS - Desinstalador de Servicio de Windows    " -ForegroundColor Yellow
Write-Host "===========================================================" -ForegroundColor Yellow

# 1. Verificar privilegios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "ERROR: Este script requiere privilegios de Administrador. Haga clic derecho en PowerShell y elija 'Ejecutar como Administrador'."
    exit 1
}

# 2. Localizar nssm.exe
$NssmExe = Join-Path $InstallDir "tools\nssm.exe"
if (-not (Test-Path $NssmExe)) {
    $NssmExe = Join-Path $InstallDir "installer\tools\nssm.exe"
}
if (-not (Test-Path $NssmExe)) {
    $CurrentDir = (Get-Location).Path
    $NssmExe = Join-Path $CurrentDir "tools\nssm.exe"
    if (-not (Test-Path $NssmExe)) {
        $NssmExe = Join-Path $CurrentDir "installer\tools\nssm.exe"
    }
}

# 3. Detener servicio si esta corriendo
$ExistingService = Get-Service -Name "OmniBridgePos" -ErrorAction SilentlyContinue
if ($ExistingService) {
    Write-Host "[1/2] Deteniendo servicio 'OmniBridgePos'..." -ForegroundColor Yellow
    Stop-Service -Name "OmniBridgePos" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
} else {
    Write-Host "[1/2] El servicio 'OmniBridgePos' no se encuentra activo." -ForegroundColor DarkGray
}

# 4. Remover servicio de Windows
if (Test-Path $NssmExe) {
    Write-Host "[2/2] Removiendo registro del servicio con NSSM..." -ForegroundColor Yellow
    & $NssmExe remove OmniBridgePos confirm | Out-Null
} else {
    Write-Host "[2/2] Removiendo servicio mediante sc.exe nativo..." -ForegroundColor Yellow
    & sc.exe delete OmniBridgePos | Out-Null
}

Write-Host "===========================================================" -ForegroundColor Green
Write-Host "  SERVICIO OMNIBRIDGEPOS REMOVIDO CON EXITO!               " -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "  Los archivos en $InstallDir se han preservado." -ForegroundColor White
Write-Host "===========================================================" -ForegroundColor Green
