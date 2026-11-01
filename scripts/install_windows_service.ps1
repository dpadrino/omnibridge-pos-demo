# Install/update NSSM without replacing local configuration or licensing data.
param(
    [string]$InstallDir = "C:\PosAgent",
    [ValidateRange(1, 65535)][int]$Port = 8989
)
$ErrorActionPreference = "Stop"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Run PowerShell as Administrator." }
$PackageDir = Split-Path $PSScriptRoot -Parent
$InstallDir = [IO.Path]::GetFullPath($InstallDir)
$SourceExe = Join-Path $PackageDir "pos-peripherals-agent.exe"
$TargetExe = Join-Path $InstallDir "pos-peripherals-agent.exe"
$TargetConfig = Join-Path $InstallDir "config.toml"
$SourceConfig = Join-Path $PackageDir "config.toml"
if (-not (Test-Path $SourceConfig -PathType Leaf)) { $SourceConfig = Join-Path $PackageDir "config.example.toml" }
$SourceTools = Join-Path $PackageDir "tools"
if (-not (Test-Path (Join-Path $SourceTools "nssm.exe") -PathType Leaf)) {
    $SourceTools = Join-Path $PackageDir "installer\tools"
}
if (-not (Test-Path $SourceExe -PathType Leaf)) { throw "Package binary missing: $SourceExe" }
if (-not (Test-Path (Join-Path $SourceTools "nssm.exe") -PathType Leaf)) { throw "Package NSSM missing." }
if (-not (Test-Path $TargetConfig -PathType Leaf) -and -not (Test-Path $SourceConfig -PathType Leaf)) { throw "Initial configuration missing." }
if (-not (Test-Path (Join-Path $PSScriptRoot "diagnose_service.ps1") -PathType Leaf)) { throw "Diagnostic script missing." }

function Invoke-Nssm([string[]]$Arguments) {
    & $NssmExe @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "NSSM failed: $($Arguments[0]) (exit $LASTEXITCODE)" }
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$Lock = Join-Path $InstallDir ".install-lock"
if (Test-Path $Lock) { throw "Another install or stale .install-lock requires operator review." }
# FileMode.CreateNew also rejects a racing installer.
$LockHandle = [IO.File]::Open($Lock, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
$Backup = Join-Path $InstallDir ("install-backup-" + [Guid]::NewGuid().ToString("N"))
$Stopped = $false
$ExistingService = @()
$NssmExe = Join-Path $SourceTools "nssm.exe"
try {
    $ExistingService = @(Get-Service | Where-Object Name -eq "OmniBridgePos")
    if ($ExistingService.Count -gt 0) {
        $PreviousDirectory = & $NssmExe get OmniBridgePos AppDirectory
        if ($LASTEXITCODE -ne 0) { throw "Existing service is not accessible through NSSM." }
        $PreviousApplication = & $NssmExe get OmniBridgePos Application
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect existing service application." }
        if ([IO.Path]::GetFullPath(($PreviousDirectory -join "").Trim()) -ne $InstallDir -or
            [IO.Path]::GetFullPath(($PreviousApplication -join "").Trim()) -ne $TargetExe) {
            throw "Existing service uses another directory/application; migrate it explicitly, not through this installer."
        }
    }
    New-Item -ItemType Directory -Path $Backup | Out-Null
    # Preserve ACLs restricting recovery files to administrators and SYSTEM.
    & icacls.exe $Backup /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Cannot secure backup directory." }
    if (Test-Path $TargetExe -PathType Leaf) { Copy-Item $TargetExe (Join-Path $Backup "pos-peripherals-agent.exe") }
    foreach ($Tool in @("nssm.exe", "SumatraPDF.exe")) {
        $PreviousTool = Join-Path $InstallDir "tools\$Tool"
        if (Test-Path $PreviousTool -PathType Leaf) { Copy-Item $PreviousTool (Join-Path $Backup $Tool) }
    }
    if ($ExistingService.Count -gt 0) {
        Stop-Service -Name OmniBridgePos
        (Get-Service OmniBridgePos).WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    }
    $Stopped = $true
    if ([IO.Path]::GetFullPath($SourceExe) -ne $TargetExe) { Copy-Item $SourceExe $TargetExe -Force }
    if (-not (Test-Path $TargetConfig -PathType Leaf)) { Copy-Item $SourceConfig $TargetConfig }
    $TargetLicense = Join-Path $InstallDir "license.key"
    $SourceLicense = Join-Path $PackageDir "license.key"
    if (-not (Test-Path $TargetLicense) -and (Test-Path $SourceLicense -PathType Leaf)) { Copy-Item $SourceLicense $TargetLicense }
    # .master_key is never copied, regenerated or removed by this installer.
    $ToolsDir = Join-Path $InstallDir "tools"
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    foreach ($Tool in @("nssm.exe", "SumatraPDF.exe")) {
        $SourceTool = Join-Path $SourceTools $Tool
        $TargetTool = Join-Path $ToolsDir $Tool
        if ((Test-Path $SourceTool -PathType Leaf) -and ([IO.Path]::GetFullPath($SourceTool) -ne $TargetTool)) {
            Copy-Item $SourceTool $TargetTool -Force
        }
    }
    $NssmExe = Join-Path $ToolsDir "nssm.exe"
    if ($ExistingService.Count -eq 0) { Invoke-Nssm @("install", "OmniBridgePos", $TargetExe) }
    Invoke-Nssm @("set", "OmniBridgePos", "Application", $TargetExe)
    Invoke-Nssm @("set", "OmniBridgePos", "AppDirectory", $InstallDir)
    Invoke-Nssm @("set", "OmniBridgePos", "Start", "SERVICE_AUTO_START")
    Invoke-Nssm @("set", "OmniBridgePos", "AppRestartDelay", "3000")
    Start-Service OmniBridgePos
    & (Join-Path $PSScriptRoot "diagnose_service.ps1") -Port $Port -WaitForStartup
    if ($LASTEXITCODE -ne 0) { throw "Startup diagnostic failed." }
    Write-Host "Service installed: manager running and HTTP live. Hardware not certified."
    Write-Host "Recovery files retained at $Backup"
} catch {
    Write-Error -ErrorAction Continue "Installation FAILED. Recovery files: $Backup. $($_.Exception.Message)"
    $OldExe = Join-Path $Backup "pos-peripherals-agent.exe"
    if ($Stopped) {
        try {
            $Service = @(Get-Service | Where-Object Name -eq "OmniBridgePos")
            if ($Service.Count -gt 0) {
                Stop-Service OmniBridgePos
                (Get-Service OmniBridgePos).WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
            }
            if (Test-Path $OldExe -PathType Leaf) {
                Copy-Item $OldExe $TargetExe -Force
                foreach ($Tool in @("nssm.exe", "SumatraPDF.exe")) {
                    $PreviousTool = Join-Path $Backup $Tool
                    if (Test-Path $PreviousTool -PathType Leaf) { Copy-Item $PreviousTool (Join-Path $InstallDir "tools\$Tool") -Force }
                }
                if ($ExistingService.Count -gt 0) {
                    Start-Service OmniBridgePos
                    & (Join-Path $PSScriptRoot "diagnose_service.ps1") -Port $Port -WaitForStartup
                    if ($LASTEXITCODE -ne 0) { throw "Previous service not live." }
                }
                Write-Host "Previous binary restored; installation remains FAILED."
            } else {
                Write-Error -ErrorAction Continue "No previous binary; failed installation left stopped."
            }
        } catch {
            Write-Error -ErrorAction Continue "Rollback FAILED: $($_.Exception.Message). Restore manually from $Backup."
        }
    }
    exit 1
} finally {
    $LockHandle.Dispose()
    Remove-Item -LiteralPath $Lock
}
