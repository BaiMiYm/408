param([Parameter(Mandatory=$true)][string]$SourceDirectory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Join-Path $projectRoot 'game'
$playlist = Get-Content -LiteralPath (Join-Path $gameRoot 'playlist.json') -Raw -Encoding utf8 | ConvertFrom-Json
$seenFiles = @{}
foreach ($entry in $playlist) {
    $info = Get-Content -LiteralPath (Join-Path $gameRoot $entry.charts[0].info.Substring(6)) -Raw -Encoding utf8 | ConvertFrom-Json
    $name = Split-Path $info.audio -Leaf
    if ($seenFiles.ContainsKey($name)) { continue }
    $seenFiles[$name] = $true
    $sourceFile = Join-Path $SourceDirectory $name
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        Write-Host "跳过缺少的文件：$name"
        continue
    }
    $hash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $info.audio_sha256) { throw "录音版本不匹配，未导入：$name" }
    $destinationFile = Join-Path $gameRoot $info.audio.Substring(6)
    if ([IO.Path]::GetFullPath($sourceFile) -ne [IO.Path]::GetFullPath($destinationFile)) {
        if ((Test-Path -LiteralPath $destinationFile) -and (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) {
            throw "目标已有不同音频，请自行备份后处理：$destinationFile"
        }
        Copy-Item -LiteralPath $sourceFile -Destination $destinationFile
    }
    Write-Host "已校验：$name"
}
