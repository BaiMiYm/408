param([string]$Godot = 'godot', [switch]$CoreOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Join-Path $projectRoot 'game'
$runtimeRoot = Join-Path $projectRoot '.local/runtime'
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$savedAppData = $env:APPDATA
try {
    $env:APPDATA = $runtimeRoot
    $testNames = if ($CoreOnly) { @('judge_test', 'sustain_test') } else {
        @('judge_test','flow_test','key_bindings_test','sustain_test','sustain_input_test','empty_input_test','challenge_test','playlist_test')
    }
    foreach ($name in $testNames) {
        $logPath = Join-Path $runtimeRoot "$name.log"
        & $Godot --headless --path $gameRoot --script "res://tests/$name.gd" --log-file $logPath
        if ($LASTEXITCODE -ne 0) { throw "测试进程失败：$name" }
        $log = Get-Content -LiteralPath $logPath -Raw
        if ($log -match 'SCRIPT ERROR|Assertion failed' -or $log -notmatch 'PASS:') { throw "测试未通过：$name" }
    }
} finally { $env:APPDATA = $savedAppData }
