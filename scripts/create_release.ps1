param(
    [string]$Version = "1.1.0"
)

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $RootDir "releases"
$OutputFile = Join-Path $ReleaseDir "AzerothDB-$Version.zip"

Write-Host "Creating release package for AzerothDB v$Version..." -ForegroundColor Cyan

if (Test-Path $ReleaseDir) {
    Remove-Item $ReleaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

$TempDir = Join-Path $ReleaseDir "AzerothDB"
New-Item -ItemType Directory -Path $TempDir | Out-Null

Write-Host "Copying files..." -ForegroundColor Yellow

Copy-Item (Join-Path $RootDir "AzerothDB.lua") $TempDir
Copy-Item (Join-Path $RootDir "AzerothDB.toc") $TempDir
Copy-Item (Join-Path $RootDir "README.md") $TempDir

$DocsDir = Join-Path $TempDir "docs"
New-Item -ItemType Directory -Path $DocsDir | Out-Null
Copy-Item (Join-Path $RootDir "docs\api.md") $DocsDir

Write-Host "Creating zip archive..." -ForegroundColor Yellow
Compress-Archive -Path $TempDir -DestinationPath $OutputFile -Force

Remove-Item $TempDir -Recurse -Force

Write-Host "Release package created: $OutputFile" -ForegroundColor Green
Write-Host "Size: $((Get-Item $OutputFile).Length / 1KB) KB" -ForegroundColor Green
