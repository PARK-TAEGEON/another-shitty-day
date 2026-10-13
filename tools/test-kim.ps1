[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GodotPath, [string]$EvidencePath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'godot-common.ps1')
$executable=Resolve-DeskBreakerGodot -GodotPath $GodotPath
$repoPath=Split-Path -Parent $PSScriptRoot
$projectPath=Join-Path $repoPath 'game'
if (-not $EvidencePath) { $EvidencePath=Join-Path $repoPath 'validation/kim' }
$null=New-Item -ItemType Directory -Force $EvidencePath
$null=Invoke-DeskBreakerGodot -Executable $executable -Arguments @('--headless','--path',$projectPath,'--editor','--import')
foreach ($check in @(
    @{File='kim_rig_regression.gd'; Marker='KIM_RIG_REGRESSION_OK'},
    @{File='wall_throw_regression.gd'; Marker='WALL_THROW_REGRESSION_OK'},
    @{File='opening_reaction_regression.gd'; Marker='OPENING_REACTION_REGRESSION_OK'},
    @{File='boss_approach_regression.gd'; Marker='BOSS_APPROACH_REGRESSION_OK'},
    @{File='boss_lecture_regression.gd'; Marker='BOSS_LECTURE_REGRESSION_OK'},
    @{File='hand_motion_regression.gd'; Marker='HAND_MOTION_REGRESSION_OK'},
    @{File='npc_office_behavior_regression.gd'; Marker='NPC_OFFICE_BEHAVIOR_REGRESSION_OK'},
    @{File='property_damage_regression.gd'; Marker='PROPERTY_DAMAGE_REGRESSION_OK'},
    @{File='social_damage_regression.gd'; Marker='SOCIAL_DAMAGE_REGRESSION_OK'},
    @{File='office_layout_regression.gd'; Marker='OFFICE_LAYOUT_REGRESSION_OK'},
    @{File='minimal_hud_regression.gd'; Marker='MINIMAL_HUD_REGRESSION_OK'}
)) {
    $testPath=Join-Path $PSScriptRoot ('tests/'+$check.File)
    $reportPath=Join-Path $EvidencePath 'kim-physics-report.json'
    $result=Invoke-DeskBreakerGodot -Executable $executable -Arguments @('--headless','--fixed-fps','60','--path',$projectPath,'--script',$testPath,'--','--kim-rig','--report',$reportPath)
    $result | Set-Content -LiteralPath (Join-Path $EvidencePath ($check.File+'.txt')) -Encoding utf8
    if ($result -notmatch $check.Marker) { throw ('No success marker: '+$check.File) }
}
Write-Host 'KIM_ENABLED_SUITE_OK (headless; visual approval is separate)'
