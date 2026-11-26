# Runs all 15 market nights headlessly.
param([string]$Godot = "godot", [switch]$KeepLogs)
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dir = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$failed = @()
for ($d = 1; $d -le 15; $d++) {
    $env:DAY = "$d"
    $log = Join-Path $dir "day_$d.log"
    & $Godot --headless --path $root "res://tools/test/DayTest.tscn" *> $log
    $code = $LASTEXITCODE
    $line = (Select-String -Path $log -Pattern '\[DAY\]' | Select-Object -Last 1).Line
    Write-Output "D$d (exit $code): $line"
    if ($code -ne 0 -or $line -notmatch '\[DAY\] PASS') {
        $failed += $d
        Select-String -Path $log -Pattern 'FAIL|SCRIPT ERROR' | Select-Object -First 6 |
            ForEach-Object { Write-Output "    $($_.Line.Trim())" }
    }
    if (-not $KeepLogs) { Remove-Item $log -Force }
}
Remove-Item Env:DAY -ErrorAction SilentlyContinue
if ($failed.Count -gt 0) { throw "Failing nights: $($failed -join ', ')" }
Write-Output "[DAY] ALL 15 NIGHTS PASS"
