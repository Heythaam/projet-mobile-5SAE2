# Kickoff

Kickoff is a Flutter football-match app with a Dart Shelf API and a shared
SQLite database. The implemented user module covers accounts, friends,
one-to-one chat, and server-backed gamification. Match creation and stadium
booking remain future product work.

## Interface direction

Kickoff's core screens follow `docs/design/kickoff_core_screens_prototypes.html`:
a flat indigo background, vivid blue match cards, warm yellow controls, and
chunky fills with a single darker bottom edge. Progress and rewards shown in
the interface come from the API rather than local presentation-only
calculations. Sporcle Party and Kalak are visual/interaction references;
Kickoff uses its own football identity and original artwork.

## User module

- Register with a username, email, and password; sign in and sign out.
- Find friends by username, send and accept friend requests, and remove friends.
- Chat privately with accepted friends. The chat refreshes for new messages
  every few seconds.
- Passwords are hashed by the API. Session tokens are stored in the app's
  platform secure storage.
- The arcade app shell includes a calendar, home dashboard, ball-action menu,
  and profile. XP and streaks are read from `GET /gamification`; match/calendar
  data uses an empty repository until match endpoints are available, so no
  sample match data is presented.
- A fresh install opens in Guest Mode so the complete presentation shell can be
  explored without credentials. Guest screens use empty states and read-only
  defaults; teammate mutations and other server-backed actions ask the visitor
  to sign in. Authenticated sessions retain the normal API-backed behavior.

## Run the API

From the project root in PowerShell:

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:JWT_SECRET = [Convert]::ToBase64String($bytes)
Set-Location backend
dart run bin/server.dart
```

The API listens on port `8080` and creates `backend/data/football_matches.sqlite`
automatically. Set `PORT` or `DB_PATH` before starting the server to override
these defaults.

## Run the Flutter app

In a second terminal from the project root:

```powershell
flutter run
```

The default API address is `http://10.0.2.2:8080`, for the Android emulator.
For a physical phone, pass the computer's reachable LAN address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

Replace the example address with the computer's actual LAN IP. The API must be
reachable from the device. Android allows HTTP only in debug builds; use HTTPS
for release deployments.

For a USB-connected Android phone, start the API on the computer, then run
`adb reverse tcp:8080 tcp:8080` and launch the app with:

```powershell
flutter run -d <device-serial> --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

If `adb` is not on `PATH`, use
`$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`.

## Tests

```powershell
flutter test
Set-Location backend
dart test
```

The API routes, SQLite schema, and gamification rules are in `backend/lib`;
the Flutter user interface, models, and API client are in `lib`.
