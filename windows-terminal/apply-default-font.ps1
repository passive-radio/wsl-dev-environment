<#
.SYNOPSIS
  Set Windows Terminal's default font (profiles.defaults.font.face) to a given
  family - by default "HackGen Console NF". Backs up settings.json first and
  only touches the first `"face": "..."` occurrence, so anything else in the
  file (color schemes, keybindings, per-profile overrides) is left untouched.

.USAGE
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File apply-default-font.ps1
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File apply-default-font.ps1 -FontFace "Cascadia Code"

.NOTES
  Works for both the Store-packaged Terminal (settings.json under
  %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\) and the
  unpackaged build (%LOCALAPPDATA%\Microsoft\Windows Terminal\).

  This does a plain regex substitution rather than a full JSON
  parse/re-serialize on purpose: PowerShell's ConvertTo-Json can silently
  reformat things (unicode escaping, key order) you didn't ask it to touch.
  If your settings.json has no existing "face" key at all (fresh install with
  no font ever set), this script leaves it alone and tells you to add it by
  hand - see the README for the manual snippet.
#>
param(
    [string]$FontFace = "HackGen Console NF"
)

$ErrorActionPreference = "Stop"

$pkg = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter "Microsoft.WindowsTerminal*" -Directory -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($pkg) {
    $path = Join-Path $pkg.FullName "LocalState\settings.json"
} else {
    $path = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
}

if (-not (Test-Path $path)) {
    throw "settings.json not found at expected locations. Is Windows Terminal installed?"
}

$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$path.bak-$stamp"
Copy-Item -Path $path -Destination $backup
Write-Host "Backup written to: $backup"

$content = [System.IO.File]::ReadAllText($path)

if ($content -notmatch '"face"\s*:\s*"[^"]*"') {
    Write-Warning 'No "face" key found in settings.json - nothing changed.'
    Write-Warning 'Add this under "profiles" -> "defaults" by hand instead:'
    Write-Warning '  "font": { "face": "' + $FontFace + '" }'
    return
}

# Replace only the FIRST occurrence (profiles.defaults.font.face is normally
# the only one; a settings.json with per-profile font overrides needs manual
# editing for those, this script won't guess which profile you meant).
$pattern = '"face"\s*:\s*"[^"]*"'
$replacement = "`"face`": `"$FontFace`""
$regex = [regex]::new($pattern)
$new = $regex.Replace($content, $replacement, 1)

[System.IO.File]::WriteAllText($path, $new, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Set default font.face -> $FontFace"
Write-Host "Windows Terminal hot-reloads settings.json, so open windows should update immediately."
