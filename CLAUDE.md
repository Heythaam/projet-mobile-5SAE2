# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` is the detailed source of truth (product rules, every API route, tournament/stadium behavior, UI direction). Read it before changing behavior; this file only adds commands and the big picture.

## Commands (PowerShell, from project root)

```powershell
flutter pub get
flutter analyze
flutter test                                   # all client tests
flutter test test/tournaments_test.dart        # single file
flutter test --plain-name "some test name"     # single test
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Backend (from `backend/`): `dart pub get`, `dart analyze`, `dart test`, `dart test test/bracket_test.dart`.

Run the API (needs `JWT_SECRET` of 32+ chars; `PORT`, `DB_PATH` optional):

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:JWT_SECRET = [Convert]::ToBase64String($bytes)
Set-Location backend
dart run bin/server.dart
```

`dart run bin/seed.dart` (in `backend/`) rebuilds seed accounts, tournaments and the Champions League bracket.

Windows gotcha: a running API locks `backend/.dart_tool/lib/sqlite3.dll`, so `dart test` and `seed.dart` fail until the API is stopped.

Android: emulator uses the default `API_BASE_URL` (`10.0.2.2:8080`); a USB device needs `adb reverse tcp:8080 tcp:8080` and `API_BASE_URL=http://127.0.0.1:8080`.

## Architecture

Two Dart projects in one repo:

- **Flutter client** (`lib/`) talks only to the **Shelf API** (`backend/`) through `lib/api_client.dart` and typed models in `lib/models.dart`. Never issue ad hoc HTTP from widgets, and never keep a client-side source of truth for accounts, friends, messages or XP.
- **Backend** (`backend/lib/`): `app.dart` (routes/handlers), `database.dart` (SQLite schema and migrations), `gamification.dart` (XP/achievements), `stadium.dart`. One shared SQLite file (`backend/data/football_matches.sqlite`, path from `database_path.dart`). Auth is bearer JWT; the client keeps the token in `flutter_secure_storage`.
- State management is plain `setState`; no Provider/Bloc/Riverpod.

Feature modules in the client:

- Shell and core screens: `lib/main.dart` (session restore, auth vs shell routing), `lib/screens/kickoff_shell.dart` (three-item nav, menu, profile).
- `lib/tournaments/` (models/services/screens/widgets, constants in `tournament_constants.dart`); reference doc `docs/tournaments.md` must be updated with any tournament change. Team-name rules are duplicated in `_teamName` (API) and `TeamName` (app) and must stay in sync.
- `lib/stadium/stadium_module.dart` + `backend/lib/stadium.dart`: deliberately isolated owner-side module. Shared files only call `createStadiumTables`, `mountStadiumRoutes` and open `StadiumModule`; stadium tables never reference users/XP/friends.
- Match UI lives in `lib/screens/match/` (screens with `match_mock_data.dart`); the empty `lib/features/match/` placeholder files were removed. There are no match endpoints yet; `lib/matches/match_repository.dart` is an empty calendar repository interface. Do not add fake matches, tournaments, or locally persisted XP as if real.

Cross-cutting rules:

- Rewards/progress shown in the UI must be granted by the API and grounded in persisted events.
- Tournaments and results have no create/record routes yet; they are inserted directly into SQLite (see seed script).
- `appRouteObserver` (`lib/app_route_observer.dart`) drives list/banner reloads when screens close or the app resumes.
- UI follows `docs/design/kickoff_core_screens_prototypes.html` (flat, `#1A1A4E` background, `#2D3A7A` panels, yellow controls, no gradients/patterns). Note `.github/copilot-instructions.md` describes an older patterned/outlined style and a Match-module prompt; where it conflicts, AGENTS.md wins.
- Behavior or setup changes need updated tests and docs; run the narrowest relevant tests plus `flutter analyze` / `dart analyze`.
