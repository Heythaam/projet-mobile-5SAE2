# Run Kickoff on a USB phone.
# sqflite_common_ffi (tests only) breaks the Android APK, so it is switched
# off while the app runs and switched back on when you quit.
# Usage (from anywhere):  .\tools\phone.ps1   [-Device <id>]
param([string]$Device = '5TQ489FYO7S8EMSO')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)
Copy-Item pubspec.yaml pubspec.yaml.bak -Force
Copy-Item pubspec.lock pubspec.lock.bak -Force
try {
  (Get-Content pubspec.yaml) -replace '^(\s*)sqflite_common_ffi:', '$1# sqflite_common_ffi:' | Set-Content pubspec.yaml
  flutter pub get
  & "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:8080
  flutter run -d $Device --dart-define=API_BASE_URL=http://127.0.0.1:8080
} finally {
  Move-Item pubspec.yaml.bak pubspec.yaml -Force
  Move-Item pubspec.lock.bak pubspec.lock -Force
  flutter pub get
}
