[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GodotPath, [switch]$IncludeLegacyChaos)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot-common.ps1')
$executable = Resolve-DeskBreakerGodot -GodotPath $GodotPath
$projectPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game'
$checks = @(
    @{ File = 'ceo_hold_regression.gd'; Marker = 'CEO_HOLD_REGRESSION_OK' },
    @{ File = 'police_hold_regression.gd'; Marker = 'POLICE_HOLD_REGRESSION_OK' },
    @{ File = 'police_arrival_regression.gd'; Marker = 'POLICE_ARRIVAL_REGRESSION_OK' },
    @{ File = 'police_arrival_damage_regression.gd'; Marker = 'POLICE_ARRIVAL_DAMAGE_REGRESSION_OK' }
)
if ($IncludeLegacyChaos) {
    Write-Host 'Running the optional isolated legacy Chaos experiment. This does not enable it in the game.'
    $checks += @{ File = 'chaos_score_regression.gd'; Marker = 'CHAOS_SCORE_REGRESSION_OK' }
}
foreach ($check in $checks) {
    $checkPath = Join-Path (Join-Path $PSScriptRoot 'tests') $check.File
    $output = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
        '--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', $checkPath
    )
    if ($output -notmatch $check.Marker) { throw ('Missing success marker for ' + $check.File) }
}
Write-Host 'All v0.3 scenario regressions passed. Native display and human play quality remain separate gates.'
