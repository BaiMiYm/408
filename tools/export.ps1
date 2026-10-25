param(
    [string]$Godot = 'godot',
    [string]$TemplateDirectory = '',
    [string]$JavaSdk = '',
    [string]$AndroidSdk = '',
    [switch]$WindowsOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Join-Path $projectRoot 'game'
$localRoot = Join-Path $projectRoot '.local'
$toolRoot = Join-Path $localRoot 'export-tools'
if (-not $TemplateDirectory) { $TemplateDirectory = $toolRoot }
if (-not $AndroidSdk) { $AndroidSdk = Join-Path $toolRoot 'android-sdk' }
if (-not $JavaSdk -and (Test-Path (Join-Path $toolRoot 'jdk17'))) {
    $JavaSdk = (Get-ChildItem (Join-Path $toolRoot 'jdk17') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'bin/java.exe') } | Select-Object -First 1).FullName
}
$environmentNames = @('APPDATA','LOCALAPPDATA','TEMP','TMP','JAVA_HOME','ANDROID_USER_HOME','GODOT_ANDROID_KEYSTORE_DEBUG_PATH','GODOT_ANDROID_KEYSTORE_DEBUG_USER','GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')
$savedEnvironment = @{}
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $env:APPDATA = Join-Path $localRoot 'build-profile'
    $env:LOCALAPPDATA = Join-Path $localRoot 'build-local'
    $env:TEMP = Join-Path $localRoot 'build-temp'
    $env:TMP = $env:TEMP
    $env:ANDROID_USER_HOME = Join-Path $localRoot 'android-user'
    $releaseRoot = Join-Path $localRoot 'releases'
    $windowsRoot = Join-Path $releaseRoot 'Windows'
    $templates = Join-Path $env:APPDATA 'Godot/export_templates/4.5.1.stable'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA,$env:TEMP,$env:ANDROID_USER_HOME,$windowsRoot,$templates,$toolRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $TemplateDirectory 'windows_release_x86_64.exe') -Destination $templates
    if (-not $WindowsOnly) {
        if (-not (Test-Path (Join-Path $JavaSdk 'bin/java.exe'))) { throw '缺少 JDK 17，请指定 -JavaSdk' }
        if (-not (Test-Path (Join-Path $AndroidSdk 'build-tools/35.0.0/apksigner.bat'))) { throw '缺少 Android build-tools 35.0.0，请指定 -AndroidSdk' }
        Copy-Item -LiteralPath (Join-Path $TemplateDirectory 'android_debug.apk') -Destination $templates
        $env:JAVA_HOME = $JavaSdk
        $signingRoot = Join-Path $localRoot 'signing'
        New-Item -ItemType Directory -Path $signingRoot -Force | Out-Null
        $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = Join-Path $signingRoot 'android-debug.keystore'
        $env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
        $env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
        if (-not (Test-Path $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH)) {
            & (Join-Path $JavaSdk 'bin/keytool.exe') -genkeypair -keystore $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
            if ($LASTEXITCODE -ne 0) { throw '测试签名密钥生成失败' }
        }
        $javaValue = ConvertTo-Json $JavaSdk.Replace('\','/') -Compress
        $sdkValue = ConvertTo-Json $AndroidSdk.Replace('\','/') -Compress
        $settings = "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]`nexport/android/java_sdk_path = $javaValue`nexport/android/android_sdk_path = $sdkValue`n"
        Set-Content -LiteralPath (Join-Path $env:APPDATA 'Godot/editor_settings-4.5.tres') -Value $settings -Encoding utf8
    }
    & $Godot --headless --editor --path $gameRoot --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot 资源导入失败' }
    $targets = [System.Collections.Generic.List[object]]::new()
    $targets.Add(@('Windows Desktop', '--export-release', (Join-Path $windowsRoot 'NeonPaws.exe'), 'windows-export.log'))
    if (-not $WindowsOnly) { $targets.Add(@('Android', '--export-debug', (Join-Path $releaseRoot 'NeonPaws-Android-arm64.apk'), 'android-export.log')) }
    foreach ($target in $targets) {
        $log = Join-Path $toolRoot $target[3]
        & $Godot --headless --path $gameRoot $target[1] $target[0] $target[2] --log-file $log
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $target[2])) { throw "导出失败：$($target[0])" }
        if ((Get-Content -LiteralPath $log -Raw) -match '(?m)^(ERROR:|SCRIPT ERROR:)') { throw "导出日志存在错误：$log" }
        Write-Host "已导出：$($target[2])"
    }
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
}
