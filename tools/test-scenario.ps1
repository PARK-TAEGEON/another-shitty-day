[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot-common.ps1')
$executable = Resolve-DeskBreakerGodot -GodotPath $GodotPath
$projectPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game'
foreach ($check in @(
    @{ File = 'chaos_score_regression.gd'; Marker = 'CHAOS_SCORE_REGRESSION_OK' },
    @{ File = 'office_scenario_regression.gd'; Marker = 'OFFICE_SCENARIO_REGRESSION_OK' },
    @{ File = 'police_arrival_regression.gd'; Marker = 'POLICE_ARRIVAL_REGRESSION_OK' }
)) {
    $checkPath = Join-Path (Join-Path $PSScriptRoot 'tests') $check.File
    $output = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
        '--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', $checkPath
    )
    if ($output -notmatch $check.Marker) { throw ('Missing success marker for ' + $check.File) }
}
Write-Host 'All three scenario regressions passed. Native display and human play quality remain separate gates.'
