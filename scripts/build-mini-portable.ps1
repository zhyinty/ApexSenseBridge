param(
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseDir = Join-Path $projectRoot "build-win\Release"
$templateDir = Join-Path $projectRoot "portable-mini"
$distDir = Join-Path $projectRoot "dist"
$stageDir = Join-Path $projectRoot "build-mini-portable"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $distDir "ApexSenseBridge-APEX4-Mini-Portable.zip"
} else {
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
}

$payload = @(
    @{ Source = (Join-Path $releaseDir "ApexSenseBridge.exe"); Name = "ApexSenseBridge.exe" },
    @{ Source = (Join-Path $releaseDir "libVIIPER.dll"); Name = "libVIIPER.dll" },
    @{ Source = (Join-Path $templateDir "Start-APEX4-Mini.cmd"); Name = "Start-APEX4-Mini.cmd" },
    @{ Source = (Join-Path $templateDir "Stop-APEX4-Mini.cmd"); Name = "Stop-APEX4-Mini.cmd" },
    @{ Source = (Join-Path $templateDir "README-APEX4-MINI.txt"); Name = "README-APEX4-MINI.txt" },
    @{ Source = (Join-Path $projectRoot "portable\Install-Drivers.cmd"); Name = "Install-Drivers.cmd" },
    @{ Source = (Join-Path $projectRoot "portable\Install-Drivers.ps1"); Name = "Install-Drivers.ps1" },
    @{ Source = (Join-Path $projectRoot "installer\driver-manifest.json"); Name = "Drivers\driver-manifest.json" },
    @{ Source = (Join-Path $projectRoot "third_party\prerequisites\USBip-0.9.7.7-x64.exe"); Name = "Drivers\USBip-0.9.7.7-x64.exe" },
    @{ Source = (Join-Path $projectRoot "third_party\prerequisites\HidHide_1.5.230_x64.exe"); Name = "Drivers\HidHide_1.5.230_x64.exe" },
    @{ Source = (Join-Path $projectRoot "third_party\prerequisites\USBIP-WIN2-LICENSE.txt"); Name = "Drivers\USBIP-WIN2-LICENSE.txt" },
    @{ Source = (Join-Path $projectRoot "third_party\prerequisites\HIDHIDE-LICENSE.txt"); Name = "Drivers\HIDHIDE-LICENSE.txt" },
    @{ Source = (Join-Path $projectRoot "LICENSE"); Name = "LICENSE.txt" },
    @{ Source = (Join-Path $releaseDir "VIIPER-LICENSE.txt"); Name = "VIIPER-LICENSE.txt" },
    @{ Source = (Join-Path $releaseDir "VIIPER-SOURCE.txt"); Name = "VIIPER-SOURCE.txt" },
    @{ Source = (Join-Path $releaseDir "VIIPER-v0.7.0-asb.patch"); Name = "VIIPER-v0.7.0-asb.patch" }
)

foreach ($item in $payload) {
    if (-not (Test-Path -LiteralPath $item.Source -PathType Leaf)) {
        throw "Mini portable payload is missing: $($item.Source)"
    }
}

if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null

foreach ($item in $payload) {
    $destination = Join-Path $stageDir $item.Name
    $destinationDirectory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }
    Copy-Item -LiteralPath $item.Source -Destination $destination
}

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}
Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $OutputPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stageDir -Recurse -Force

$hash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
Write-Host "Built APEX 4 Mini portable package:"
Write-Host "  $OutputPath"
Write-Host "SHA-256: $hash"
