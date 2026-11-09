# tools

- `phone.ps1`: runs the app on a USB phone (start the API first: `cd backend; dart run bin/server.dart`).
  It disables `sqflite_common_ffi` while running, because that test-only package
  stops Gradle from packaging `libflutter.so`, and restores `pubspec.*` when you quit.
- Tests and `flutter analyze` run normally: `flutter test`.
