<#
.SYNOPSIS
  Install "HackGen Console NF" for the current Windows user (no admin rights
  needed). Uses the same Shell.Application font-install API Explorer's
  right-click "Install" uses, so it registers correctly under
  HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts.

.USAGE
  From Windows PowerShell:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File install-hackgen-font.ps1

  From inside WSL (this script is meant to be run on the Windows side, but
  WSL can invoke it through interop):
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ./install-hackgen-font.ps1)"

.NOTES
  Source: https://github.com/yuru7/HackGen
  Installs only the "Console" variant (HackGenConsoleNF-{Regular,Bold}.ttf) -
  the one HackGen's own docs point at for terminal use, since it normalizes
  symbol widths for monospace grids. The plain (non-Console) and "35" variants
  in the same release are intentionally not installed; grab them yourself from
  the release zip if you want them.
#>
param(
    [string]$Version = "2.10.0"
)

$ErrorActionPreference = "Stop"

$zipUrl = "https://github.com/yuru7/HackGen/releases/download/v$Version/HackGen_NF_v$Version.zip"
$work   = Join-Path $env:TEMP "HackGenInstall"
$zipPath = Join-Path $work "HackGen_NF.zip"

New-Item -ItemType Directory -Force -Path $work | Out-Null

Write-Host "Downloading $zipUrl ..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

Write-Host "Extracting ..."
Expand-Archive -Path $zipPath -DestinationPath $work -Force

$releaseDir = Get-ChildItem -Path $work -Directory |
    Where-Object { $_.Name -like "HackGen_NF*" } |
    Select-Object -First 1
if (-not $releaseDir) {
    throw "Could not find the extracted HackGen_NF_v$Version directory under $work"
}

$fontsToInstall = @("HackGenConsoleNF-Regular.ttf", "HackGenConsoleNF-Bold.ttf")

$Shell = New-Object -ComObject Shell.Application
$FontsFolder = $Shell.Namespace(0x14)   # CSIDL_FONTS; falls back to per-user without admin

foreach ($f in $fontsToInstall) {
    $path = Join-Path $releaseDir.FullName $f
    if (-not (Test-Path $path)) {
        Write-Warning "Expected font file not found: $path (release layout may have changed)"
        continue
    }
    Write-Host "Installing $f ..."
    $FontsFolder.CopyHere($path, 0x10)   # 0x10 = no UI / no confirmation dialogs
}

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Done. Font family name to use in your terminal/editor: 'HackGen Console NF'"
Write-Host "Verify with:"
Write-Host '  Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" | Select-Object -Property "*HackGen*"'
