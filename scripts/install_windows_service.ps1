# OmniBridge POS - Instalador Automatizado de Servicio de Windows (NSSM)
# Requiere ejecucion en PowerShell como Administrador

param(
    [string]$InstallDir = "C:\PosAgent"
)

$ErrorActionPreference = "Stop"

Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  OmniBridge POS - Instalador de Servicio de Windows       " -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan

# 1. Verificar privilegios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "ERROR: Este script requiere privilegios de Administrador. Haga clic derecho en PowerShell y elija 'Ejecutar como Administrador'."
    exit 1
}

$CurrentDir = (Get-Location).Path

# 2. Determinar directorio de instalacion
if (-not (Test-Path $InstallDir)) {
    Write-Host "[1/5] Creando directorio de instalacion: $InstallDir..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
} else {
    Write-Host "[1/5] Directorio de destino verificado: $InstallDir" -ForegroundColor Green
}

# 3. Copiar binario y archivos si se ejecuta desde otra carpeta (ej. Desktop o instalador extraido)
$CurrentExe = Join-Path $CurrentDir "pos-peripherals-agent.exe"
$TargetExe = Join-Path $InstallDir "pos-peripherals-agent.exe"

if ((Test-Path $CurrentExe) -and ($CurrentDir -ne (Get-Item $InstallDir).FullName)) {
    Write-Host "[2/5] Copiando archivos a $InstallDir..." -ForegroundColor Yellow
    Copy-Item $CurrentExe $TargetExe -Force
    if (Test-Path (Join-Path $CurrentDir "config.toml")) {
        Copy-Item (Join-Path $CurrentDir "config.toml") $InstallDir -Force
    } elseif (Test-Path (Join-Path $CurrentDir "config.example.toml")) {
        Copy-Item (Join-Path $CurrentDir "config.example.toml") (Join-Path $InstallDir "config.toml") -Force
    }
    if (Test-Path (Join-Path $CurrentDir "license.key")) {
        Copy-Item (Join-Path $CurrentDir "license.key") $InstallDir -Force
    }
} else {
    Write-Host "[2/5] Verificando archivos de ejecucion..." -ForegroundColor Green
}

if (-not (Test-Path $TargetExe)) {
    Write-Error "ERROR: No se encontro 'pos-peripherals-agent.exe' en $InstallDir"
    exit 1
}

# 4. Preparar utilidades (tools\nssm.exe y tools\SumatraPDF.exe)
$ToolsDir = Join-Path $InstallDir "tools"
$InstallerTools = Join-Path $InstallDir "installer\tools"

if (-not (Test-Path $ToolsDir)) {
    if (Test-Path $InstallerTools) {
        Write-Host "[3/5] Preparando carpeta de herramientas (tools)..." -ForegroundColor Yellow
        Copy-Item -Recurse $InstallerTools $ToolsDir
    } else {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }
} else {
    Write-Host "[3/5] Carpeta de herramientas (tools) verificada." -ForegroundColor Green
}

$NssmExe = Join-Path $ToolsDir "nssm.exe"
if (-not (Test-Path $NssmExe)) {
    if (Test-Path (Join-Path $InstallerTools "nssm.exe")) {
        $NssmExe = Join-Path $InstallerTools "nssm.exe"
    } else {
        Write-Error "ERROR: No se encontro 'nssm.exe' en $ToolsDir ni en $InstallerTools"
        exit 1
    }
}

# 5. Detener servicio previo si ya existia
Write-Host "[4/5] Configurando Servicio de Windows 'OmniBridgePos'..." -ForegroundColor Yellow
$ExistingService = Get-Service -Name "OmniBridgePos" -ErrorAction SilentlyContinue
if ($ExistingService) {
    Write-Host "      Deteniendo instancia anterior del servicio..." -ForegroundColor DarkYellow
    Stop-Service -Name "OmniBridgePos" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# 6. Registrar o actualizar parametros en NSSM
& $NssmExe install OmniBridgePos "$TargetExe" 2>$null | Out-Null
& $NssmExe set OmniBridgePos AppDirectory "$InstallDir" | Out-Null
& $NssmExe set OmniBridgePos Description "OmniBridge POS - Agente Universal de Perifericos (Bascula, Tickets, Etiquetas y Gaveta)" | Out-Null
& $NssmExe set OmniBridgePos Start SERVICE_AUTO_START | Out-Null
& $NssmExe set OmniBridgePos AppRestartDelay 3000 | Out-Null

# 7. Iniciar el servicio
Write-Host "[5/5] Iniciando servicio..." -ForegroundColor Yellow
Start-Service -Name "OmniBridgePos"
Start-Sleep -Seconds 2

$Status = Get-Service -Name "OmniBridgePos"
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "  SERVICIO INSTALADO Y EJECUTANDOSE CON EXITO!             " -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "  Servicio        : $($Status.Name)" -ForegroundColor White
Write-Host "  Estado          : $($Status.Status)" -ForegroundColor Green
Write-Host "  Directorio      : $InstallDir" -ForegroundColor White
Write-Host "  Dashboard Local : http://127.0.0.1:8989/" -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Green
