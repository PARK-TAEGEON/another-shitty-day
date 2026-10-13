[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GodotPath, [string]$EvidencePath='validation/kim-integration')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'godot-common.ps1')
$executable=Resolve-DeskBreakerGodot -GodotPath $GodotPath
$projectPath=Join-Path (Split-Path -Parent $PSScriptRoot) 'game'
$null=New-Item -ItemType Directory -Force $EvidencePath
$summary=@()
$null=Invoke-DeskBreakerGodot -Executable $executable -Arguments @('--headless','--path',$projectPath,'--editor','--import')
$checks=@('wall_throw_regression','opening_reaction_regression','boss_approach_regression','boss_lecture_regression','hand_motion_regression','npc_office_behavior_regression','property_damage_regression','social_damage_regression','office_layout_regression','minimal_hud_regression','ceo_hold_regression','police_hold_regression','police_arrival_regression','police_arrival_damage_regression','kim_demo_integration')
foreach($mode in @('default','health-only','legacy')) {
    $flags=@()
    if($mode -eq 'health-only') {$flags=@('--kim-health-only')}
    if($mode -eq 'legacy') {$flags=@('--kim-legacy')}
    foreach($test in $checks) {
        $result=Invoke-DeskBreakerGodot -Executable $executable -Arguments (@('--headless','--fixed-fps','60','--path',$projectPath,'--script',(Join-Path $PSScriptRoot "tests/$test.gd"),'--')+$flags)
        $result | Set-Content -LiteralPath (Join-Path $EvidencePath "$mode-$test.txt") -Encoding utf8
        $marker=$test.ToUpper()+'_OK'
        if($result -notmatch $marker) {throw "Missing marker $marker in $mode"}
        $summary+=@{mode=$mode;test=$test;result='PASS'}
    }
}
foreach($test in @('kim_rig_regression','kim_restart_regression')) {
    $result=Invoke-DeskBreakerGodot -Executable $executable -Arguments @('--headless','--fixed-fps','60','--path',$projectPath,'--script',(Join-Path $PSScriptRoot "tests/$test.gd"),'--','--report',(Join-Path $EvidencePath 'physics.json'))
    $result | Set-Content -LiteralPath (Join-Path $EvidencePath "$test.txt") -Encoding utf8
    if($result -notmatch ($test.ToUpper()+'_OK')) {throw "Missing marker $test"}
    $summary+=@{mode='default';test=$test;result='PASS'}
}
$summary | ConvertTo-Json | Set-Content (Join-Path $EvidencePath 'summary.json') -Encoding utf8
Write-Host 'KIM_INTEGRATION_MATRIX_OK: 3 modes x (10 baseline + 4 scenario + real kick comparison), physics and 5 reloads'
