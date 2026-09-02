param(
    [int]$Seconds = 0
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
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`""
    )
    if ($Seconds -gt 0) {
        $elevationArguments += @("-Seconds", [string]$Seconds)
    }
    $elevated = Start-Process -FilePath $powerShell -ArgumentList $elevationArguments `
        -Verb RunAs -Wait -PassThru
    exit $elevated.ExitCode
}

$bridge = Join-Path $PSScriptRoot "ApexSenseBridge.exe"
$cliCandidates = @(
    (Join-Path $env:ProgramFiles "Nefarius Software Solutions\HidHide\x64\HidHideCLI.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Nefarius Software Solutions\HidHide\x64\HidHideCLI.exe")
)
$cli = $cliCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not (Test-Path -LiteralPath $bridge -PathType Leaf)) {
    throw "找不到桥接程序：$bridge"
}
if ([string]::IsNullOrWhiteSpace($cli)) {
    throw "找不到 HidHideCLI.exe。请先运行 Install-Drivers.cmd，然后重启 Windows。"
}

function Invoke-HidHide([string[]]$Arguments) {
    $result = @(& $cli @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "HidHide 命令执行失败：$($Arguments -join ' ')"
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
            throw "找不到需要加入 HidHide 白名单的程序：$app"
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
        throw "没有找到 APEX 4 的 XInput 游戏接口。请确认手柄处于 XInput 模式。"
    }
    foreach ($device in $apexDevices) {
        $instance = [string]$device.deviceInstancePath
        if ($originalDevices -notcontains $instance) {
            Invoke-HidHide @("--dev-hide", $instance) | Out-Null
            $addedDevices += $instance
        }
    }

    Invoke-HidHide @("--cloak-on") | Out-Null
    Write-Host "HidHide 已临时启用：游戏只能看到虚拟 DS5。"
    Write-Host "桥接器和飞智空间站仍可访问 APEX 4。"
    Write-Host ""
    $bridgeArguments = @(
        "bridge-triggers", "--space-station", "--xinput-index", "0",
        "--virtual-backend", "integrated"
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
        Write-Host "HidHide 已恢复到启动前状态。"
    }
    catch {
        Write-Warning "HidHide 自动恢复失败：$($_.Exception.Message)"
        Write-Warning "请打开 HidHide Configuration Client，关闭 Enable device hiding。"
    }
}

exit $bridgeExitCode
