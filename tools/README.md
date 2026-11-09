# tools

- `phone.ps1`: runs the app on a USB phone (start the API first: `cd backend; dart run bin/server.dart`).
  It disables `sqflite_common_ffi` while running, because that test-only package
  stops Gradle from packaging `libflutter.so`, and restores `pubspec.*` when you quit.
- Tests and `flutter analyze` run normally: `flutter test`.

## Sample data

Everything lives in one file, `assets/sample_data.json`: 20 users, 5
tournaments, 14 public matches at real places around Tunis (with coordinates, so
"near me" works) and 10 challenges.

- Users and tournaments (backend): stop the server, then from `backend/` run
  `dart run bin/seed.dart`. Every sample user has the password `Test1234!`.
- Matches and challenges (phone): `.\tools\phone.ps1` starts the app with
  `SAMPLE_DATA=true`, which loads them once. Without that flag the app never
  loads samples.
