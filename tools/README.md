# tools

- `phone.ps1`: runs the app on a USB phone.
  It disables `sqflite_common_ffi` while running, because that test-only package
  stops Gradle from packaging `libflutter.so`, and restores `pubspec.*` when you quit.
- Tests and `flutter analyze` run normally: `flutter test`.

## Sample data

Everything lives in one file, `assets/sample_data.json`: 14 public matches at real places around Tunis (with coordinates, so
"near me" works) and 10 challenges.

- Matches and challenges: `.\tools\phone.ps1` starts the app with
  `SAMPLE_DATA=true`, which loads them once. Without that flag the app never
  loads samples.
