# Shared helpers for Windows PowerShell 5.1 and PowerShell 7.
# All settings apply to the current command only. No user environment is changed.

Set-StrictMode -Version Latest

function Invoke-DeskBreakerGodot {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [int]$TimeoutSeconds = 300
    )

    # Write logs to files so a noisy Godot process cannot fill a pipe and stall.
    # Each test is stopped if it is still running after TimeoutSeconds.
    $stdout = New-TemporaryFile
    $stderr = New-TemporaryFile
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $proc = Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru -NoNewWindow -RedirectStandardOutput $stdout.FullName -RedirectStandardError $stderr.FullName
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            $null = $proc.WaitForExit()
            $tail = @()
            $tail += @(Get-Content -LiteralPath $stdout.FullName -Tail 40 -ErrorAction SilentlyContinue)
            $tail += @(Get-Content -LiteralPath $stderr.FullName -Tail 40 -ErrorAction SilentlyContinue)
            throw "Godot exceeded ${TimeoutSeconds}s and was stopped.`n$($tail -join "`n")"
        }
        $outText = ''
        $errText = ''
        if (Test-Path -LiteralPath $stdout.FullName) {
            $read = Get-Content -LiteralPath $stdout.FullName -Raw -ErrorAction SilentlyContinue
            if ($read) { $outText = [string]$read }
        }
        if (Test-Path -LiteralPath $stderr.FullName) {
            $readErr = Get-Content -LiteralPath $stderr.FullName -Raw -ErrorAction SilentlyContinue
            if ($readErr) { $errText = [string]$readErr }
        }
        $text = ($outText + "`n" + $errText).Trim()
        if ($text) { Write-Host $text }
        if ($proc.ExitCode -ne 0) {
            throw "Godot exited with code $($proc.ExitCode). See the output above."
        }
        if ($text -match '(?m)^\s*(SCRIPT ERROR|ERROR):') {
            throw 'Godot reported an error despite returning zero. See the output above.'
        }
        return $text
    }
    finally {
        $ErrorActionPreference = $previousPreference
        Remove-Item -LiteralPath $stdout.FullName, $stderr.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-DeskBreakerGodot {
    param([Parameter(Mandatory = $true)][string]$GodotPath)

    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot executable not found: $GodotPath"
    }
    $executable = (Resolve-Path -LiteralPath $GodotPath).Path
    $version = Invoke-DeskBreakerGodot -Executable $executable -Arguments @('--version')
    if ($version.Trim() -notmatch '^4\.7\.2\.stable(?:\.|$)') {
        throw 'This project requires Godot 4.7.2 stable. On Windows, pass its console executable for reliable logs.'
    }
    return $executable
}
