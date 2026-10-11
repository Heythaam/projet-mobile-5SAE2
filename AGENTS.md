# Kickoff project context

## Product

Kickoff is a Flutter app for organizing football matches with friends. The
implemented user module includes account registration/sign-in, friend requests,
teammates, direct chat, and server-backed career progression. Match/stadium
booking is part of the product direction but is not implemented yet.

## Architecture

- Flutter client: `lib/`
- Dart Shelf API: `backend/`
- Shared central SQLite database, defaulting to
  `backend/data/football_matches.sqlite`
- The app calls the API; do not add a second client-side source of truth for
  accounts, friends, messages, or XP.
- Password hashing and authenticated bearer-token routes belong on the API.
  The Flutter client stores the session token with `flutter_secure_storage`.
- Set `JWT_SECRET` before starting the API. It must be at least 32 characters.
  `PORT` and `DB_PATH` can override API defaults.
- Flutter's `API_BASE_URL` defaults to `http://10.0.2.2:8080` for the Android
  emulator. For a USB-connected Android device use
  `http://127.0.0.1:8080` with `adb reverse tcp:8080 tcp:8080`; a phone cannot
  use the emulator-only `10.0.2.2` address.

## Implemented behavior

- Auth endpoints: registration, login, session restoration (`GET /me`), logout
  on the client.
- Social endpoints: friends, friend requests, request acceptance/removal, and
  direct messages with incremental polling.
- `GET /gamification` returns server-owned XP, level/rank, progress, daily and
  best streaks, message count, and achievement progress/unlock timestamps.
- XP/achievements are awarded for defined events (registration, accepted
  friendship, messages, and streak milestones). Keep rewards grounded in
  persisted events; do not invent progress from presentation-only state.
- The three-item app shell presents a calendar repository interface with an
  empty implementation until match/stadium endpoints exist. Never add sample
  matches or locally persisted gamification values as if they were real.

## UI direction

- The core screen reference is `docs/design/kickoff_core_screens_prototypes.html`.
  Match its flat 360-dp layouts and tokens: solid `#1A1A4E` background,
  `#2D3A7A` panels, vivid blue match cards, warm yellow controls, and a single
  thicker bottom edge for chunky fills. Avoid background patterns, gradients,
  full panel outlines, and offset shadows. Use 500/600 weights, readable text,
  and icon-first navigation with accessible 48-dp touch targets.
- Sporcle Party and Kalak are mood/interaction references only. Use original
  Kickoff copy, football iconography, and compositions; do not copy their names,
  logos, characters, artwork, or exact screens.
- Keep auth, home, calendar, and profile consistent with the supplied mockups.
- Gamification should reflect real backend state. Do not imply a mission grants
  XP unless the API actually awards it.

## Key files

- `lib/main.dart`: app setup, theme, session restoration and auth/shell routing.
- `lib/api_client.dart`, `lib/models.dart`: typed client API and response
  models.
- `lib/auth_screen.dart`: registration and sign-in.
- `lib/screens/kickoff_shell.dart`: three-item navigation, menu, profile and
  server-backed gamification loading.
- `lib/screens/`, `lib/matches/`: core screen widgets and the match model/
  repository boundary.
- `lib/home_screen.dart`: team and invitations.
- `lib/chat_screen.dart`: one-to-one chat.
- `backend/lib/app.dart`: Shelf routes and handlers.
- `backend/lib/database.dart`: SQLite schema and migrations.
- `backend/lib/gamification.dart`: XP and achievement rules.
- `test/`, `backend/test/`: Flutter widget and API/database tests.

## Development and validation (PowerShell)

From the project root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

For backend checks, from `backend/`:

```powershell
dart pub get
dart analyze
dart test
```

To start the API from the project root:

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:JWT_SECRET = [Convert]::ToBase64String($bytes)
Set-Location backend
dart run bin/server.dart
```

On the known USB Android device, `adb.exe` is under
`$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`. Device serial used for
manual testing: `5TQ489FYO7S8EMSO`. Establish `adb reverse` before launching a
build that targets `127.0.0.1:8080`.

When changing UI or API behavior, update the relevant tests and documentation.
Run the narrowest relevant tests plus `flutter analyze` or `dart analyze`; build
the Android APK when validating Android-specific UI or networking.
