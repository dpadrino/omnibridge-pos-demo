#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [ValidateNotNullOrEmpty()]
    [string]$PrinterBaseName = "POS-80",

    [string]$KeepPrinterName = "",

    [switch]$Repair,

    [switch]$SetDefault,

    [switch]$CleanInstall,

    [switch]$TestPrint,

    [switch]$Interactive,

    [string]$DriverPath = "C:\POS Printer Driver V7.17",

    [ValidateRange(5, 120)]
    [int]$WaitSeconds = 30
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PrinterBaseName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $copySuffix = '(?i)\s*(?:\(\s*(?:copy|copia)(?:\s+(?:of|de))?\s*\d+\s*\)|-\s*(?:copy|copia)(?:\s+(?:of|de))?\s*\d+|\s+(?:copy|copia)(?:\s+(?:of|de))?\s*\d+)\s*$'
    return ([regex]::Replace($Name.Trim(), $copySuffix, "")).Trim()
}

function Get-PrinterFamilyState {
    param([Parameter(Mandatory = $true)][string]$BaseName)

    $printers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object {
        [string]::Equals(
            (Get-PrinterBaseName -Name $_.Name),
            $BaseName,
            [StringComparison]::OrdinalIgnoreCase
        )
    })
    $cimPrinters = @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue)

    foreach ($printer in $printers) {
        $cim = $cimPrinters | Where-Object {
            [string]::Equals($_.Name, $printer.Name, [StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1
        $jobs = @(Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue)
        $status = [string]$printer.PrinterStatus
        $pendingDeletion = $status -match "PendingDeletion"
        $workOffline = $false
        $isDefault = $false
        if ($null -ne $cim) {
            $workOffline = [bool]$cim.WorkOffline
            $isDefault = [bool]$cim.Default
        }
        $normalStatus = [string]::IsNullOrWhiteSpace($status) -or $status -eq "Normal" -or $status -eq "0"

        [pscustomobject]@{
            Name            = $printer.Name
            PortName        = $printer.PortName
            DriverName      = $printer.DriverName
            PrinterStatus   = $status
            WorkOffline     = $workOffline
            IsDefault       = $isDefault
            Jobs            = $jobs.Count
            PendingDeletion = $pendingDeletion
            IsUsable        = $normalStatus -and -not $workOffline -and -not $pendingDeletion
        }
    }
}

function Get-UsbPrinterPorts {
    try {
        @(Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "USB*" } | Select-Object -ExpandProperty Name)
    } catch {
        @()
    }
}

function Get-SpoolerStuckFiles {
    $spoolDir = Join-Path $env:SystemRoot "System32\spool\PRINTERS"
    if (Test-Path $spoolDir) {
        return @(Get-ChildItem -Path $spoolDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".spl", ".shd") })
    }
    return @()
}

function Show-PrinterFamilyState {
    param(
        [Parameter(Mandatory = $true)][array]$State,
        [Parameter(Mandatory = $true)][string]$BaseName
    )

    Write-Host "`n=== 1. Estado de Colas de Impresion: $BaseName ===" -ForegroundColor Cyan
    if ($State.Count -eq 0) {
        Write-Host "No se encontraron colas de impresion para '$BaseName'." -ForegroundColor Red
        return
    }

    $State |
        Select-Object Name, PortName, DriverName, PrinterStatus, WorkOffline, IsDefault, Jobs, IsUsable |
        Format-Table -AutoSize
}

function Show-SystemPortAndSpoolerDiagnostics {
    param([Parameter(Mandatory = $true)][string]$BaseName)

    Write-Host "`n=== 2. Diagnostico del Spooler y Puertos USB ===" -ForegroundColor Cyan

    # Spooler Service
    $spoolSvc = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue
    $spoolStatus = if ($null -ne $spoolSvc) { $spoolSvc.Status } else { "No encontrado" }
    if ($spoolStatus -eq "Running") {
        Write-Host "Servicio Spooler (Cola de impresion): EN EJECUCION [OK]" -ForegroundColor Green
    } else {
        Write-Host "Servicio Spooler: $spoolStatus [ALERTA: Debe estar en ejecucion]" -ForegroundColor Red
    }

    # Stuck Files
    $stuckFiles = @(Get-SpoolerStuckFiles)
    if ($stuckFiles.Count -eq 0) {
        Write-Host "Archivos en cola de Spooler (PRINTERS): 0 [LIMPIO]" -ForegroundColor Green
    } else {
        Write-Host "Archivos en cola de Spooler trabados: $($stuckFiles.Count) [ALERTA: Puede bloquear la impresion]" -ForegroundColor Yellow
        foreach ($f in $stuckFiles) {
            Write-Host "   - $($f.Name) ($($f.Length) bytes)" -ForegroundColor Gray
        }
    }

    # USB Ports
    $usbPorts = @(Get-UsbPrinterPorts)
    if ($usbPorts.Count -gt 0) {
        Write-Host "Puertos USB de impresion detectados: $($usbPorts -join ', ') [OK]" -ForegroundColor Green
    } else {
        Write-Host "Puertos USB de impresion detectados: NINGUNO [AVISO: Verifique el cable USB de la POS-80]" -ForegroundColor Yellow
    }

    # Check Family Port
    $familyPrinters = @(Get-PrinterFamilyState -BaseName $BaseName)
    foreach ($p in $familyPrinters) {
        if ($p.PortName -notlike "USB*") {
            Write-Host "ADVERTENCIA: La cola '$($p.Name)' esta asociada al puerto '$($p.PortName)'." -ForegroundColor Yellow
            Write-Host "   Si la impresora esta conectada por USB, ¡NO imprimira! Debe reasignarse a un puerto USB." -ForegroundColor Yellow
        }
        if ($p.WorkOffline) {
            Write-Host "ADVERTENCIA: '$($p.Name)' esta marcada como 'Fuera de linea' (WorkOffline)." -ForegroundColor Yellow
        }
    }

    # Windows Default Printer Mode (LegacyDefaultPrinterMode)
    $regMode = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -ErrorAction SilentlyContinue).LegacyDefaultPrinterMode
    if ($regMode -eq 1) {
        Write-Host "Gestion automatica de impresora por Windows: DESACTIVADA (Modo Fijo) [OK]" -ForegroundColor Green
    } else {
        Write-Host "Gestion automatica de impresora por Windows: ACTIVA [AVISO: Windows puede cambiar la impresora predeterminada arbitrariamente]" -ForegroundColor Yellow
    }

    # Installer directory check
    $candidates = @("C:\POS Printer Driver V7.17", "C:\POS Printer Driver", "C:\POS_Printer_Driver", "C:\Driver")
    $foundDir = $null
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $foundDir = $c
            break
        }
    }
    if ($null -ne $foundDir) {
        Write-Host "Directorio del instalador detectado: $foundDir [DISPONIBLE]" -ForegroundColor Green
    } else {
        Write-Host "Directorio del instalador: No encontrado en rutas habituales (esperado en C:\POS Printer Driver V7.17)" -ForegroundColor Gray
    }
}

function Stop-OmniBridgeIfRunning {
    $service = Get-Service -Name "OmniBridgePos" -ErrorAction SilentlyContinue
    if ($null -ne $service -and $service.Status -eq "Running") {
        Write-Host "Deteniendo temporalmente OmniBridgePos..." -ForegroundColor Yellow
        Stop-Service -Name "OmniBridgePos" -Force
        (Get-Service -Name "OmniBridgePos").WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
        return $true
    }
    return $false
}

function Remove-PrinterFamilyJobs {
    param([Parameter(Mandatory = $true)][array]$State)

    foreach ($printer in $State) {
        $jobs = @(Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue)
        if ($jobs.Count -gt 0) {
            Write-Host "Cancelando $($jobs.Count) trabajo(s) de '$($printer.Name)'..." -ForegroundColor Yellow
            $jobs | Remove-PrintJob -Confirm:$false
        }
    }
}

function Restart-PrintSpooler {
    Write-Host "Reiniciando el servicio Spooler..." -ForegroundColor Yellow
    Restart-Service -Name "Spooler" -Force
    (Get-Service -Name "Spooler").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
    Start-Sleep -Seconds 2
}

function Reset-PrinterOnlineState {
    param([Parameter(Mandatory = $true)][string]$PrinterName)

    try {
        Set-Printer -Name $PrinterName -WorkOffline $false -ErrorAction SilentlyContinue
    } catch {}

    try {
        $wmi = Get-WmiObject -Class Win32_Printer -Filter "Name='$PrinterName'" -ErrorAction SilentlyContinue
        if ($wmi -and $wmi.WorkOffline) {
            $wmi.WorkOffline = $false
            $wmi.Put() | Out-Null
        }
    } catch {}

    try {
        Resume-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue
    } catch {}
}

function Set-PermanentDefaultPrinter {
    param([Parameter(Mandatory = $true)][string]$PrinterName)

    Write-Host "Configurando '$PrinterName' como impresora predeterminada inmutable..." -ForegroundColor Yellow

    # Desactivar 'Permitir que Windows administre mi impresora predeterminada' en el registro
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "LegacyDefaultPrinterMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "No se pudo fijar LegacyDefaultPrinterMode en registro: $($_.Exception.Message)"
    }

    # Establecer vía CIM
    $wmiPrinter = Get-CimInstance Win32_Printer | Where-Object {
        [string]::Equals($_.Name, $PrinterName, [StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1

    if ($null -ne $wmiPrinter) {
        Invoke-CimMethod -InputObject $wmiPrinter -MethodName SetDefaultPrinter | Out-Null
        Write-Host "Impresora '$PrinterName' establecida como predeterminada exitosamente." -ForegroundColor Green
    } else {
        # Fallback WScript.Network
        try {
            $wsh = New-Object -ComObject WScript.Network
            $wsh.SetDefaultPrinter($PrinterName)
            Write-Host "Impresora '$PrinterName' establecida como predeterminada via WScript." -ForegroundColor Green
        } catch {
            Write-Warning "No se pudo establecer como predeterminada: $($_.Exception.Message)"
        }
    }
}

function Fix-PrinterPortIfInvalid {
    param(
        [Parameter(Mandatory = $true)][string]$PrinterName,
        [Parameter(Mandatory = $true)][string]$CurrentPort
    )

    $usbPorts = @(Get-UsbPrinterPorts)
    if ($CurrentPort -notlike "USB*" -and $usbPorts.Count -gt 0) {
        $targetPort = $usbPorts[0]
        Write-Warning "La impresora '$PrinterName' esta en el puerto no-USB '$CurrentPort', pero hay puertos USB disponibles: $($usbPorts -join ', ')."
        Write-Host "Reasignando automaticamente '$PrinterName' al puerto '$targetPort'..." -ForegroundColor Yellow
        try {
            Set-Printer -Name $PrinterName -PortName $targetPort -ErrorAction Stop
            Write-Host "Puerto reasignado exitosamente a '$targetPort'." -ForegroundColor Green
        } catch {
            Write-Warning "No se pudo reasignar automaticamente el puerto: $($_.Exception.Message)"
        }
    }
}

function Find-Survivor {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()][array]$State,
        [Parameter(Mandatory = $false)]
        [string]$RequestedName
    )

    $usable = @($State | Where-Object IsUsable)
    if (-not [string]::IsNullOrWhiteSpace($RequestedName)) {
        $selected = @($usable | Where-Object {
            [string]::Equals($_.Name, $RequestedName, [StringComparison]::OrdinalIgnoreCase)
        })
        if ($selected.Count -ne 1) {
            throw "La cola indicada en -KeepPrinterName no existe o no esta utilizable: $RequestedName"
        }
        return $selected[0]
    }

    if ($usable.Count -eq 1) {
        return $usable[0]
    }
    if ($usable.Count -eq 0) {
        return $null
    }

    $defaultPrinters = @($usable | Where-Object IsDefault)
    if ($defaultPrinters.Count -eq 1) {
        return $defaultPrinters[0]
    }

    $names = ($usable.Name | Sort-Object) -join "', '"
    throw "Hay varias colas utilizables y no es seguro elegir una automaticamente. Repita con -KeepPrinterName '$names'."
}

function Invoke-PlugAndPlayScan {
    $pnputil = Join-Path $env:SystemRoot "System32\pnputil.exe"
    if (-not (Test-Path $pnputil -PathType Leaf)) {
        Write-Warning "pnputil.exe no esta disponible; no se puede solicitar un nuevo escaneo Plug and Play."
        return
    }

    Write-Host "Solicitando escaneo Plug and Play a Windows..." -ForegroundColor Yellow
    & $pnputil /scan-devices | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "pnputil fallo durante el escaneo Plug and Play (codigo $LASTEXITCODE)."
    }
}

function Wait-ForUsablePrinter {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName,
        [Parameter(Mandatory = $true)][int]$Seconds
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        $state = @(Get-PrinterFamilyState -BaseName $BaseName)
        if (@($state | Where-Object IsUsable).Count -gt 0) {
            return $state
        }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)

    return @(Get-PrinterFamilyState -BaseName $BaseName)
}

function Invoke-PrinterTestPrint {
    param([Parameter(Mandatory = $true)][string]$PrinterName)

    Write-Host "`n=== Prueba de Impresion en '$PrinterName' ===" -ForegroundColor Cyan
    $p = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($null -eq $p) {
        Write-Host "[ERROR] La impresora '$PrinterName' no esta instalada en este equipo." -ForegroundColor Red
        return
    }

    Write-Host "Enviando pagina de prueba nativa de Windows a '$PrinterName' (Puerto: $($p.PortName))..." -ForegroundColor Yellow
    try {
        $process = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /k /n `"$PrinterName`"" -PassThru -NoNewWindow
        $process.WaitForExit(6000) | Out-Null
        Start-Sleep -Seconds 2

        $jobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue)
        if ($jobs.Count -eq 0) {
            Write-Host "[EXITO] El trabajo de impresion fue procesado y entregado al puerto $($p.PortName)." -ForegroundColor Green
            Write-Host "Compruebe si el papel salio fisicamente cortado de la impresora." -ForegroundColor Cyan
        } else {
            Write-Warning "El trabajo de prueba quedo retenido en cola ($($jobs.Count) trabajo(s))."
            Write-Host "Verificaciones recomendadas:" -ForegroundColor Yellow
            Write-Host "  1. ¿La impresora esta encendida con luz azul/verde fija (sin error de papel)?" -ForegroundColor White
            Write-Host "  2. ¿El puerto actual ($($p.PortName)) coincide con la conexion USB fisica?" -ForegroundColor White
            Write-Host "  3. Ejecute la opcion de Reparacion o Limpieza profunda si el puerto esta bloqueado." -ForegroundColor White
        }
    } catch {
        Write-Host "[ERROR] Fallo al despachar la pagina de prueba: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-RepairProcess {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName,
        [bool]$SetDefaultFlag = $true,
        [string]$KeepName = "",
        [int]$WaitSec = 30
    )

    if (-not (Test-IsAdministrator)) {
        throw "Debe ejecutar PowerShell como Administrador para realizar la reparacion."
    }

    Write-Host "`n=== Iniciando Reparacion y Saneamiento de '$BaseName' ===" -ForegroundColor Cyan

    $initialState = @(Get-PrinterFamilyState -BaseName $BaseName)
    $omniBridgeWasRunning = $false
    try {
        $omniBridgeWasRunning = Stop-OmniBridgeIfRunning
        Remove-PrinterFamilyJobs -State $initialState

        if (@($initialState | Where-Object PendingDeletion).Count -gt 0) {
            Restart-PrintSpooler
        }

        $state = @(Get-PrinterFamilyState -BaseName $BaseName)
        $stillPending = @($state | Where-Object PendingDeletion)
        if ($stillPending.Count -gt 0) {
            foreach ($printer in $stillPending) {
                Write-Host "Solicitando eliminar cola pendiente '$($printer.Name)'..." -ForegroundColor Yellow
                try {
                    Remove-Printer -Name $printer.Name -Confirm:$false
                } catch {
                    Write-Warning "Windows aun retiene '$($printer.Name)': $($_.Exception.Message)"
                }
            }
            Restart-PrintSpooler
            $state = @(Get-PrinterFamilyState -BaseName $BaseName)
        }

        $survivor = Find-Survivor -State $state -RequestedName $KeepName
        if ($null -eq $survivor) {
            Invoke-PlugAndPlayScan
            $state = @(Wait-ForUsablePrinter -BaseName $BaseName -Seconds $WaitSec)
            $survivor = Find-Survivor -State $state -RequestedName $KeepName
        }
        if ($null -eq $survivor) {
            throw "No aparecio una cola utilizable. Conecte la POS-80 al puerto USB definitivo, espere a que Windows la reconozca y repita el proceso."
        }

        # Eliminar colas duplicadas
        foreach ($printer in @($state | Where-Object {
            -not [string]::Equals($_.Name, $survivor.Name, [StringComparison]::OrdinalIgnoreCase)
        })) {
            $jobs = @(Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue)
            if ($jobs.Count -gt 0) {
                $jobs | Remove-PrintJob -Confirm:$false
            }
            Write-Host "Eliminando cola duplicada '$($printer.Name)'..." -ForegroundColor Yellow
            Remove-Printer -Name $printer.Name -Confirm:$false
        }

        # Normalizar nombre
        if (-not [string]::Equals($survivor.Name, $BaseName, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Renombrando '$($survivor.Name)' como '$BaseName'..." -ForegroundColor Yellow
            Rename-Printer -Name $survivor.Name -NewName $BaseName
        }

        # Restaurar estado online y reanudar
        Reset-PrinterOnlineState -PrinterName $BaseName

        # Verificar y corregir puerto si estaba en LPT o COM habiendo USB activo
        Fix-PrinterPortIfInvalid -PrinterName $BaseName -CurrentPort $survivor.PortName

        # Configurar como predeterminada inmutable si se solicito
        if ($SetDefaultFlag) {
            Set-PermanentDefaultPrinter -PrinterName $BaseName
        }

        $finalState = @(Get-PrinterFamilyState -BaseName $BaseName)
        Show-PrinterFamilyState -State $finalState -BaseName $BaseName

        $verified = $finalState.Count -eq 1 -and
            $finalState[0].IsUsable -and
            [string]::Equals($finalState[0].Name, $BaseName, [StringComparison]::OrdinalIgnoreCase)
        if (-not $verified) {
            throw "La verificacion final fallo: Windows no dejo una unica cola utilizable llamada '$BaseName'."
        }

        Write-Host "`nREPARACION COMPLETADA CON EXITO: '$BaseName' es la unica cola activa y configurada." -ForegroundColor Green
    } finally {
        if ($omniBridgeWasRunning) {
            Write-Host "Reiniciando servicio OmniBridgePos..." -ForegroundColor Yellow
            Start-Service -Name "OmniBridgePos"
            (Get-Service -Name "OmniBridgePos").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
        }
    }
}

function Invoke-CleanSlateForReinstall {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName,
        [string]$DriverPath = "C:\POS Printer Driver V7.17"
    )

    if (-not (Test-IsAdministrator)) {
        throw "Debe ejecutar PowerShell como Administrador para realizar la limpieza profunda."
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  INICIANDO LIMPIEZA PROFUNDA DEL SPOOLER Y COLAS POS-80" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan

    $omniRunning = Stop-OmniBridgeIfRunning

    Write-Host "1. Deteniendo servicio Spooler de Windows..." -ForegroundColor Yellow
    Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue
    (Get-Service -Name "Spooler").WaitForStatus("Stopped", [TimeSpan]::FromSeconds(15))

    Write-Host "2. Purgando archivos trabados en el Spooler (C:\Windows\System32\spool\PRINTERS)..." -ForegroundColor Yellow
    $spoolDir = Join-Path $env:SystemRoot "System32\spool\PRINTERS"
    if (Test-Path $spoolDir) {
        $deleted = 0
        Get-ChildItem -Path $spoolDir -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                $deleted++
            } catch {
                Write-Warning "No se pudo eliminar $($_.Name): $($_.Exception.Message)"
            }
        }
        Write-Host "   Archivos purgados del Spooler: $deleted" -ForegroundColor Green
    }

    Write-Host "3. Reiniciando servicio Spooler..." -ForegroundColor Yellow
    Start-Service -Name "Spooler"
    (Get-Service -Name "Spooler").WaitForStatus("Running", [TimeSpan]::FromSeconds(20))

    Write-Host "4. Eliminando todas las colas de impresion existentes de '$BaseName'..." -ForegroundColor Yellow
    $printers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "*$BaseName*" -or $_.Name -like "*POS*80*" -or $_.Name -like "*POS-58*"
    })
    foreach ($p in $printers) {
        try {
            Write-Host "   Removiendo cola '$($p.Name)'..." -ForegroundColor Yellow
            Remove-Printer -Name $p.Name -Confirm:$false -ErrorAction Stop
        } catch {
            Write-Warning "No se pudo remover cola $($p.Name): $($_.Exception.Message)"
        }
    }

    # Desactivar administracion automatica de impresora por Windows
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name "LegacyDefaultPrinterMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "`n[OK] El sistema de impresion quedo 100% LIMPIO y desbloqueado." -ForegroundColor Green

    # Detectar instalador
    $candidates = @($DriverPath, "C:\POS Printer Driver", "C:\POS_Printer_Driver", "C:\Driver")
    $foundInstaller = $null
    foreach ($dir in $candidates) {
        if (Test-Path $dir) {
            $exes = @(Get-ChildItem -Path $dir -Filter "*.exe" -File -Recurse -ErrorAction SilentlyContinue)
            if ($exes.Count -gt 0) {
                $foundInstaller = $exes[0].FullName
                break
            }
        }
    }

    if ($null -ne $foundInstaller) {
        Write-Host "`nInstalador detectado: $foundInstaller" -ForegroundColor Cyan
        Write-Host "REGLAS CLAVE PARA LA INSTALACION:" -ForegroundColor Yellow
        Write-Host "  1. Seleccione el modelo: POS-80" -ForegroundColor White
        Write-Host "  2. Seleccione el puerto: USB001 (o el puerto USB activo de mayor numero)" -ForegroundColor White
        Write-Host "  3. Marque la casilla: 'Set as Default Printer' (Establecer como predeterminada)" -ForegroundColor White
        Write-Host "  4. Finalice el instalador." -ForegroundColor White
        Write-Host ""

        $launch = Read-Host "¿Desea iniciar el instalador del driver ahora? (S/N)"
        if ($launch -match "^[sSyY]") {
            Write-Host "Ejecutando instalador..." -ForegroundColor Yellow
            Start-Process -FilePath $foundInstaller
            Write-Host "Complete el asistente de instalacion del fabricante..." -ForegroundColor Gray
            Read-Host "Cuando haya finalizado de instalar el driver, presione [ENTER] para verificar la salud"
            Invoke-RepairProcess -BaseName $BaseName -SetDefaultFlag $true -KeepName "" -WaitSec 30
        }
    } else {
        Write-Host "`nNo se localizo un instalador ejecutable en '$DriverPath'." -ForegroundColor Yellow
        Write-Host "Puede ejecutar manualmente su instalador desde C:\POS Printer Driver V7.17 y asegurarse de:" -ForegroundColor White
        Write-Host "  - Elegir modelo: POS-80" -ForegroundColor White
        Write-Host "  - Elegir puerto: USB001 o USB correspondiente" -ForegroundColor White
        Write-Host "  - Marcar como predeterminada" -ForegroundColor White
    }

    if ($omniRunning) {
        Write-Host "Reiniciando servicio OmniBridgePos..." -ForegroundColor Yellow
        Start-Service -Name "OmniBridgePos" -ErrorAction SilentlyContinue
    }
}

function Install-POS80DirectFromFolder {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName,
        [string]$DriverPath = "C:\POS Printer Driver V7.17"
    )

    if (-not (Test-IsAdministrator)) {
        throw "Debe ejecutar PowerShell como Administrador para instalar el controlador."
    }

    Write-Host "`n=== Instalacion Directa de '$BaseName' (Sin Asistente Visual) ===" -ForegroundColor Cyan

    $infFiles = @(Get-ChildItem -Path $DriverPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue)
    if ($infFiles.Count -eq 0) {
        # Probar rutas alternativas
        foreach ($alt in @("C:\POS Printer Driver", "C:\POS_Printer_Driver", "C:\Driver")) {
            if (Test-Path $alt) {
                $infFiles = @(Get-ChildItem -Path $alt -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue)
                if ($infFiles.Count -gt 0) {
                    $DriverPath = $alt
                    break
                }
            }
        }
    }

    if ($infFiles.Count -gt 0) {
        Write-Host "1. Registrando controlador INF en el almacen de Windows..." -ForegroundColor Yellow
        foreach ($inf in $infFiles) {
            Write-Host "   Importando $($inf.Name)..." -ForegroundColor Gray
            & pnputil.exe /add-driver "$($inf.FullName)" /install | Out-Null
        }
    } else {
        Write-Host "1. No se localizaron archivos .inf sueltos; verificando controladores ya registrados..." -ForegroundColor Yellow
    }

    # 2. Localizar driver registrado
    $posDrivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "*$BaseName*" -or $_.Name -like "*POS*80*" -or $_.Name -like "*POS80*" -or $_.Name -like "*POS*"
    })

    if ($posDrivers.Count -eq 0) {
        throw "No se encontro ningun controlador registrado para POS-80. Asegurese de haber descomprimido el instalador en '$DriverPath'."
    }

    $driverName = $posDrivers[0].Name
    Write-Host "2. Controlador seleccionado: '$driverName' [OK]" -ForegroundColor Green

    # 3. Detectar puerto USB
    $usbPorts = @(Get-UsbPrinterPorts)
    $targetPort = if ($usbPorts.Count -gt 0) { $usbPorts[0] } else { "USB001" }
    Write-Host "3. Puerto de impresion asignado: '$targetPort' [OK]" -ForegroundColor Green

    # 4. Remover colas previas con ese nombre si existen
    $existing = Get-Printer -Name $BaseName -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Write-Host "   Removiendo cola anterior de '$BaseName'..." -ForegroundColor Yellow
        Remove-Printer -Name $BaseName -Confirm:$false -ErrorAction SilentlyContinue
    }

    # 5. Crear la impresora
    Write-Host "4. Creando la cola de impresion '$BaseName'..." -ForegroundColor Yellow
    Add-Printer -Name $BaseName -DriverName $driverName -PortName $targetPort -ErrorAction Stop
    Write-Host "   Impresora '$BaseName' creada exitosamente." -ForegroundColor Green

    # 6. Ponerla en linea y predeterminada
    Reset-PrinterOnlineState -PrinterName $BaseName
    Set-PermanentDefaultPrinter -PrinterName $BaseName

    Write-Host "`n[EXITO] Instalacion directa completada. '$BaseName' esta lista y predeterminada." -ForegroundColor Green
}

function Show-InteractiveMenu {
    param([Parameter(Mandatory = $true)][string]$BaseName)

    while ($true) {
        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host "  OMNIBRIDGE POS - SALUD Y GESTION DE IMPRESORA POS-80" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Host: $env:COMPUTERNAME   |   Impresora objetivo: $BaseName" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [1] Diagnosticar estado (colas, puertos USB, trabajos y predeterminada)" -ForegroundColor White
        Write-Host "  [2] Reparar y unificar (dejar 1 sola POS-80, desatascar Spooler y predeterminada)" -ForegroundColor White
        Write-Host "  [3] Limpieza profunda (purgar Spooler y colas para reinstalar)" -ForegroundColor White
        Write-Host "  [4] Instalacion DIRECTA de POS-80 (saltarse el instalador visual si no muestra opciones)" -ForegroundColor Yellow
        Write-Host "  [5] Enviar impresion de prueba nativa a '$BaseName'" -ForegroundColor White
        Write-Host "  [6] Salir" -ForegroundColor White
        Write-Host ""
        $opt = Read-Host "Seleccione una opcion [1-6]"

        switch ($opt) {
            "1" {
                $state = @(Get-PrinterFamilyState -BaseName $BaseName)
                Show-PrinterFamilyState -State $state -BaseName $BaseName
                Show-SystemPortAndSpoolerDiagnostics -BaseName $BaseName
                Write-Host "`nPresione [ENTER] para volver al menu principal..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "2" {
                try {
                    Invoke-RepairProcess -BaseName $BaseName -SetDefaultFlag $true -KeepName "" -WaitSec 30
                } catch {
                    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
                }
                Write-Host "`nPresione [ENTER] para volver al menu principal..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "3" {
                try {
                    Invoke-CleanSlateForReinstall -BaseName $BaseName -DriverPath "C:\POS Printer Driver V7.17"
                } catch {
                    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
                }
                Write-Host "`nPresione [ENTER] para volver al menu principal..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "4" {
                try {
                    Install-POS80DirectFromFolder -BaseName $BaseName -DriverPath "C:\POS Printer Driver V7.17"
                } catch {
                    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
                }
                Write-Host "`nPresione [ENTER] para volver al menu principal..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "5" {
                Invoke-PrinterTestPrint -PrinterName $BaseName
                Write-Host "`nPresione [ENTER] para volver al menu principal..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "6" {
                Write-Host "Finalizando..." -ForegroundColor Gray
                return
            }
            default {
                Write-Warning "Opcion no valida. Elija un numero del 1 al 6."
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ==============================================================================
# ENTRADA PRINCIPAL Y DESPACHO
# ==============================================================================

if ($env:OS -ne "Windows_NT") {
    throw "Este script solo es compatible con Windows."
}
if (-not (Get-Command Get-Printer -ErrorAction SilentlyContinue)) {
    throw "El modulo PrintManagement no esta disponible en este Windows."
}

$PrinterBaseName = Get-PrinterBaseName -Name $PrinterBaseName

# 1. Modo Interactivo
if ($Interactive) {
    Show-InteractiveMenu -BaseName $PrinterBaseName
    exit 0
}

# 2. Modo Limpieza Profunda para Reinstalacion
if ($CleanInstall) {
    Invoke-CleanSlateForReinstall -BaseName $PrinterBaseName -DriverPath $DriverPath
    exit 0
}

# 3. Modo Pagina de Prueba
if ($TestPrint) {
    Invoke-PrinterTestPrint -PrinterName $PrinterBaseName
    exit 0
}

# 4. Modo Reparacion
if ($Repair) {
    if (-not (Test-IsAdministrator)) {
        throw "Ejecute PowerShell como Administrador para usar -Repair."
    }
    if (-not $PSCmdlet.ShouldProcess(
        "familia de impresoras '$PrinterBaseName'",
        "cancelar sus trabajos, consolidar duplicados y reiniciar el Spooler"
    )) {
        exit 0
    }

    $shouldSetDefault = $SetDefault.IsPresent -or ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey("SetDefault"))
    Invoke-RepairProcess -BaseName $PrinterBaseName -SetDefaultFlag $shouldSetDefault -KeepName $KeepPrinterName -WaitSec $WaitSeconds
    exit 0
}

# 5. Modo Diagnostico (por defecto si no se pasa ninguna bandera de accion)
$initialState = @(Get-PrinterFamilyState -BaseName $PrinterBaseName)
Show-PrinterFamilyState -State $initialState -BaseName $PrinterBaseName
Show-SystemPortAndSpoolerDiagnostics -BaseName $PrinterBaseName

$healthy = $initialState.Count -eq 1 -and
    $initialState[0].IsUsable -and
    [string]::Equals($initialState[0].Name, $PrinterBaseName, [StringComparison]::OrdinalIgnoreCase)

if ($healthy) {
    Write-Host "`nSALUDABLE: existe una sola cola utilizable con el nombre esperado '$PrinterBaseName'." -ForegroundColor Green
    exit 0
}

Write-Warning "Se requiere correccion. Ejecute 'printer_health.bat' o use el parametro -Repair."
Write-Host "La reparacion cancela solamente los trabajos de la familia '$PrinterBaseName' y conserva el driver." -ForegroundColor Gray
Write-Host "Para soporte sin comandos, ejecute scripts\printer_health.bat con doble clic." -ForegroundColor Cyan
exit 2
