param(
    [string]$WowDir = $env:WOW_FOREVER_DIR
)

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $PSScriptRoot

if (-not $WowDir) {
    $Candidates = @(
        "C:\Program Files (x86)\World of Warcraft\_forever_",
        "C:\Program Files\World of Warcraft\_forever_",
        "D:\World of Warcraft\_forever_",
        "C:\Program Files (x86)\World of Warcraft\_classic_"
    )
    foreach ($c in $Candidates) {
        if (Test-Path $c) {
            $WowDir = $c
            break
        }
    }
}

if (-not $WowDir -or -not (Test-Path $WowDir)) {
    Write-Error "WoW Forever 폴더를 찾을 수 없습니다. 예: .\scripts\install.ps1 'C:\Program Files (x86)\World of Warcraft\_forever_'"
    exit 1
}

$AddonsDir = Join-Path $WowDir "Interface\AddOns"
New-Item -ItemType Directory -Force -Path $AddonsDir | Out-Null

$LegacyAddon = Join-Path $AddonsDir "AntigravityWoW"
if (Test-Path $LegacyAddon) {
    Remove-Item -Recurse -Force $LegacyAddon
}

$TargetAddon = Join-Path $AddonsDir "WoWAGY"
if (Test-Path $TargetAddon) {
    Remove-Item -Recurse -Force $TargetAddon
}

Copy-Item -Recurse -Force (Join-Path $RepoDir "AddOn\WoWAGY") $TargetAddon
Copy-Item -Force (Join-Path $RepoDir "AGENTS.md") (Join-Path $AddonsDir "AGENTS.md")

Write-Host "✅ wow-agy (WoWAGY) 설치 완료: $TargetAddon"
Write-Host "브릿지 실행 (uv 권장): uv run wow-agy-daemon --wow-dir `"$WowDir`""
Write-Host "(또는 Python 직접 실행): python `"$RepoDir\bridge\daemon.py`" --wow-dir `"$WowDir`""
