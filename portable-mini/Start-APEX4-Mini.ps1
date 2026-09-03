param(
    [int]$Seconds = 0,
    [ValidateRange(0, 200)][int]$TriggerStrength = 100,
    [ValidateRange(0, 200)][int]$RumbleStrength = 100
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    $powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $elevationArguments = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
        "-File", "`"$PSCommandPath`""
    )
    if ($Seconds -gt 0) {
        $elevationArguments += @("-Seconds", [string]$Seconds)
    }
    $elevationArguments += @("-TriggerStrength", [string]$TriggerStrength)
    $elevationArguments += @("-RumbleStrength", [string]$RumbleStrength)
    $elevated = Start-Process -FilePath $powerShell -ArgumentList $elevationArguments `
        -Verb RunAs -Wait -PassThru
    exit $elevated.ExitCode
}

$startupLog = Join-Path $PSScriptRoot "Start-APEX4-Mini.log"
$transcriptStarted = $false
try {
    Start-Transcript -LiteralPath $startupLog -Append | Out-Null
    $transcriptStarted = $true
}
catch {}

trap {
    Write-Host ""
    Write-Host ("Startup failed: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host ("Detailed log: " + $startupLog) -ForegroundColor Yellow
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch {}
    }
    exit 1
}

$bridge = Join-Path $PSScriptRoot "ApexSenseBridge.exe"
$cliCandidates = @(
    (Join-Path $env:ProgramFiles "Nefarius Software Solutions\HidHide\x64\HidHideCLI.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Nefarius Software Solutions\HidHide\x64\HidHideCLI.exe")
)
$cli = $cliCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not (Test-Path -LiteralPath $bridge -PathType Leaf)) {
    throw "Bridge executable not found: $bridge"
}
if ([string]::IsNullOrWhiteSpace($cli)) {
    throw "HidHideCLI.exe was not found. Run Install-Drivers.cmd and restart Windows first."
}

function Invoke-HidHide([string[]]$Arguments) {
    $result = @(& $cli @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "HidHide command failed: $($Arguments -join ' ')"
    }
    return $result
}

function Parse-RegisteredValues([string[]]$Lines, [string]$Prefix) {
    $values = @()
    foreach ($line in $Lines) {
        if ($line -match ("^" + [regex]::Escape($Prefix) + ' "(.*)"$')) {
            $values += $Matches[1]
        }
    }
    return $values
}

$originalCloak = (Invoke-HidHide @("--cloak-state") | Select-Object -First 1).Trim()
$originalInverse = (Invoke-HidHide @("--inv-state") | Select-Object -First 1).Trim()
$originalApps = Parse-RegisteredValues (Invoke-HidHide @("--app-list")) "--app-reg"
$originalDevices = Parse-RegisteredValues (Invoke-HidHide @("--dev-list")) "--dev-hide"
$addedApps = @()
$addedDevices = @()
$bridgeExitCode = 1

try {
    Invoke-HidHide @("--cloak-off") | Out-Null
    Invoke-HidHide @("--inv-off") | Out-Null

    $allowedApps = @(
        $bridge,
        (Join-Path $env:ProgramFiles "Flydigi Space Station\Flydigi Space Station.exe"),
        (Join-Path $env:ProgramFiles "Flydigi Space Station\SpaceStationService.exe")
    )
    foreach ($app in $allowedApps) {
        if (-not (Test-Path -LiteralPath $app -PathType Leaf)) {
            throw "Required HidHide allowlisted application was not found: $app"
        }
        if ($originalApps -notcontains $app) {
            Invoke-HidHide @("--app-reg", $app) | Out-Null
            $addedApps += $app
        }
    }

    $gamingJson = Invoke-HidHide @("--dev-gaming") | Out-String
    $gamingGroups = $gamingJson | ConvertFrom-Json
    $apexDevices = @($gamingGroups | ForEach-Object { $_.devices } | Where-Object {
        $_.present -eq $true -and $_.gamingDevice -eq $true -and
        $_.baseContainerDeviceInstancePath -match '^USB\\VID_045E&PID_028E\\FLYDIGI_'
    })
    if ($apexDevices.Count -eq 0) {
        throw "No APEX 4 XInput game interface was found. Confirm that the controller is in XInput mode."
    }
    foreach ($device in $apexDevices) {
        $instance = [string]$device.deviceInstancePath
        if ($originalDevices -notcontains $instance) {
            Invoke-HidHide @("--dev-hide", $instance) | Out-Null
            $addedDevices += $instance
        }
    }

    Invoke-HidHide @("--cloak-on") | Out-Null
    Write-Host "HidHide is active temporarily; the game can see only the virtual DualSense."
    Write-Host "ApexSenseBridge and Flydigi Space Station retain access to APEX 4."
    Write-Host ""
    $bridgeArguments = @(
        "bridge-triggers", "--space-station", "--xinput-index", "0",
        "--virtual-backend", "integrated",
        "--trigger-strength", [string]$TriggerStrength,
        "--rumble-strength", [string]$RumbleStrength
    )
    if ($Seconds -gt 0) {
        $bridgeArguments += @("--seconds", [string]$Seconds)
    }
    & $bridge @bridgeArguments
    $bridgeExitCode = $LASTEXITCODE
}
finally {
    try {
        Invoke-HidHide @("--cloak-off") | Out-Null
        foreach ($device in $addedDevices) {
            Invoke-HidHide @("--dev-unhide", $device) | Out-Null
        }
        foreach ($app in $addedApps) {
            Invoke-HidHide @("--app-unreg", $app) | Out-Null
        }
        if ($originalInverse -eq "--inv-on") {
            Invoke-HidHide @("--inv-on") | Out-Null
        } else {
            Invoke-HidHide @("--inv-off") | Out-Null
        }
        if ($originalCloak -eq "--cloak-on") {
            Invoke-HidHide @("--cloak-on") | Out-Null
        } else {
            Invoke-HidHide @("--cloak-off") | Out-Null
        }
        Write-Host "HidHide has been restored to its previous state."
    }
    catch {
        Write-Warning "Automatic HidHide restoration failed: $($_.Exception.Message)"
        Write-Warning "Open HidHide Configuration Client and turn off Enable device hiding."
    }
}

if ($transcriptStarted) {
    try { Stop-Transcript | Out-Null } catch {}
}
exit $bridgeExitCode
