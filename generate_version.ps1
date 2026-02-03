# generate_version.ps1
# Generates scripts/core/Version.gd with the current git description

$GitVersion = git describe --tags --always --dirty --match "v*"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: git describe failed. Using fallback."
    $GitVersion = "v0.0.0-dev"
}

$Content = @"
class_name Version

const BUILD_VERSION = "$GitVersion"
"@

$Path = "scripts/core/Version.gd"
Set-Content -Path $Path -Value $Content -Encoding UTF8
Write-Host "Generated $Path with version: $GitVersion"
