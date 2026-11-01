param(
    [ValidateRange(1, 65535)][int]$Port = 8989,
    [switch]$WaitForStartup
)
$ErrorActionPreference = "Stop"
$Attempts = 1
if ($WaitForStartup) { $Attempts = 10 }
$ManagerOk = $false
$HttpOk = $false
for ($Attempt = 0; $Attempt -lt $Attempts; $Attempt++) {
    $Service = @(Get-Service | Where-Object Name -eq "OmniBridgePos")
    $ManagerOk = $Service.Count -eq 1 -and $Service[0].Status -eq "Running"
    $HttpOk = $false
    try {
        $Response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/api/v1/health/live" -TimeoutSec 2
        $Body = $Response.Content | ConvertFrom-Json
        $HttpOk = $Response.StatusCode -eq 200 -and $Body.status -eq "ok"
    } catch {
        if ($Attempt -eq $Attempts - 1) {
            Write-Warning "HTTP liveness failed (connection, HTTP status or JSON contract)."
        }
    }
    if ($ManagerOk -and $HttpOk) { break }
    if ($Attempt -lt $Attempts - 1) { Start-Sleep -Seconds 1 }
}
Write-Host "Service manager running: $ManagerOk"
Write-Host "HTTP liveness on port ${Port}: $HttpOk"
Write-Host "Read-only: no printing, weighing, drawer pulse or queue cleanup."
Write-Host "Liveness does not certify hardware, authentication or installed build."
if (-not ($ManagerOk -and $HttpOk)) { exit 1 }
exit 0
