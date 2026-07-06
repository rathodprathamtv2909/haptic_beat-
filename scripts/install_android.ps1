param(
    [switch]$Release
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir '..')
$javaHome = 'C:\Program Files\Android\Android Studio\jbr'
$adbDir = 'C:\Users\ratho\AppData\Local\Android\Sdk\platform-tools'

Set-Location $projectRoot
$env:JAVA_HOME = $javaHome
$env:Path = "$javaHome\bin;$adbDir;$env:Path"

$buildMode = if ($Release) { 'release' } else { 'debug' }
$buildCommand = if ($Release) { 'flutter build apk --release' } else { 'flutter build apk --debug' }
$apkPath = if ($Release) { Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk' } else { Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk' }

Write-Host "Running: $buildCommand"
Invoke-Expression $buildCommand
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$devices = & adb devices | Select-String 'device$|devices$'
if (-not $devices) {
    Write-Host "No Android device/emulator detected. APK ready at $apkPath"
    exit 0
}

Write-Host "Installing $apkPath"
& adb install -r $apkPath
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Installed successfully."
