<#
.SYNOPSIS
Import and run smoke, accepted scene, office layout, NPC, property and social-loss regressions.
.EXAMPLE
.\tools\test.ps1 -GodotPath 'C:\Tools\Godot\Godot_console.exe'
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GodotPath)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot-common.ps1')
$executable = Resolve-DeskBreakerGodot -GodotPath $GodotPath
$projectPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game'

Write-Host 'Importing project resources...'
$null = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--path', $projectPath, '--editor', '--import'
)
Write-Host 'Running smoke scenario...'
$result = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--path', $projectPath, '--', '--smoke-test'
)
if ($result -notmatch 'DESK_BREAKER_SMOKE_OK:') {
    throw 'The smoke scenario did not report success. Do not treat this run as a pass.'
}
Write-Host 'Running held-item wall and camera-pickup regression...'
$regressionPath = Join-Path $PSScriptRoot 'tests\wall_throw_regression.gd'
$regression = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--path', $projectPath, '--script', $regressionPath
)
if ($regression -notmatch 'WALL_THROW_REGRESSION_OK') {
    throw 'The wall-throw regression did not report success. Do not treat this run as a pass.'
}
Write-Host 'Running first desk-slam reaction regression...'
$openingPath = Join-Path $PSScriptRoot 'tests\opening_reaction_regression.gd'
$opening = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', $openingPath
)
if ($opening -notmatch 'OPENING_REACTION_REGRESSION_OK') {
    throw 'The opening-reaction regression did not report success. Do not treat this run as a pass.'
}
Write-Host 'Running boss travel, physical clearance, and settled-arrival regression...'
$bossPath = Join-Path $PSScriptRoot 'tests\boss_approach_regression.gd'
$boss = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', $bossPath
)
if ($boss -notmatch 'BOSS_APPROACH_REGRESSION_OK') {
    throw 'The boss-approach regression did not report success. Do not treat this run as a pass.'
}
Write-Host 'Running boss lecture, player activity, caption interruption, and reset regression...'
$lecturePath = Join-Path $PSScriptRoot 'tests\boss_lecture_regression.gd'
$lecture = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', $lecturePath
)
if ($lecture -notmatch 'BOSS_LECTURE_REGRESSION_OK') {
    throw 'The boss-lecture regression did not report success. Do not treat this run as a pass.'
}
Write-Host 'Running hand contact, B/A timing, and pause-cancellation regression...'
$handsPath = Join-Path $PSScriptRoot 'tests\hand_motion_regression.gd'
$hands = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
    '--headless', '--path', $projectPath, '--script', $handsPath
)
if ($hands -notmatch 'HAND_MOTION_REGRESSION_OK') {
    throw 'The hand-motion regression did not report success. Do not treat this run as a pass.'
}
foreach ($check in @(
    @{ File = 'npc_office_behavior_regression.gd'; Marker = 'NPC_OFFICE_BEHAVIOR_REGRESSION_OK' },
    @{ File = 'property_damage_regression.gd'; Marker = 'PROPERTY_DAMAGE_REGRESSION_OK' },
    @{ File = 'social_damage_regression.gd'; Marker = 'SOCIAL_DAMAGE_REGRESSION_OK' },
    @{ File = 'office_layout_regression.gd'; Marker = 'OFFICE_LAYOUT_REGRESSION_OK' },
    @{ File = 'minimal_hud_regression.gd'; Marker = 'MINIMAL_HUD_REGRESSION_OK' },
    @{ File = 'ui_stars_result_regression.gd'; Marker = 'UI_STARS_RESULT_REGRESSION_OK' }
)) {
    Write-Host ('Running ' + $check.File + '...')
    $checkPath = Join-Path (Join-Path $PSScriptRoot 'tests') $check.File
    $checkOutput = Invoke-DeskBreakerGodot -Executable $executable -Arguments @(
        '--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', $checkPath
    )
    if ($checkOutput -notmatch $check.Marker) {
        throw ('The ' + $check.File + ' check did not report success.')
    }
}
Write-Host 'Import, smoke and all ten regressions passed. Visual, audio, native Windows launch and play-feel checks remain separate.'
