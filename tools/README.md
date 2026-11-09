# tools

- `phone.ps1`: runs the app on a USB phone (start the API first: `cd backend; dart run bin/server.dart`).
  It disables `sqflite_common_ffi` while running, because that test-only package
  stops Gradle from packaging `libflutter.so`, and restores `pubspec.*` when you quit.
- Tests and `flutter analyze` run normally: `flutter test`.

## seed-users.ps1

With the backend running, `.\tools\seed-users.ps1` registers 20 sample players
(`demo_sami`, `demo_yassine`, ...; password `Passw0rd!`). In the app, matches
and challenges have an "Add sample ..." button: on the Join tab when the public
list is empty, and the sparkle icon on the Challenges screen.
