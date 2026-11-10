# CLAUDE.md

Guidance for Claude Code in this repository.

`AGENTS.md` is the detailed source of truth (architecture, behavior, UI, git
rules). Read it before changing behavior; this file adds commands and the big
picture.

## Commands (PowerShell, from project root)

```powershell
flutter pub get
flutter analyze
flutter test                                   # all tests
flutter test test/services/stadium/stadium_firestore_test.dart   # single file
flutter test --plain-name "some test name"     # single test
flutter build apk --debug
.\tools\phone.ps1                              # run on the USB phone
```

There is no backend to start. Android Firebase setup needs
`android/app/google-services.json` and the debug SHA-1 registered (see
`readme.md`).

## Architecture

One Flutter project. Data: SQFlite on each phone plus Firebase Auth and Cloud
Firestore as the shared source, so several phones show the same data.

- `lib/main.dart` builds the Firestore-backed services when
  `FirebaseCloudSync.start()` succeeds, otherwise no-op services (guest mode).
- Screens use small interfaces (`TournamentService`, `StadiumApi`,
  `StadiumDirectory`, `FriendsService`, `AccountService`, `ChallengeCloud`,
  `CloudSync`). Tests swap in in-memory fakes.
- Rules are pure Dart: `TournamentRules`, `TournamentFixtures`, `StadiumRules`.
  Tournaments and stadiums are one Firestore document each, changed only through
  `store.mutate` (a transaction).
- State management is plain `setState` / `ChangeNotifier`.
- `lib/services/api_client.dart` and the old HTTP services are legacy base classes only.
  Never add calls to a Kickoff server.

Layout (same as the course): `lib/entities` (data classes), `lib/bd` (SQFlite),
`lib/services` (http, Firestore, SharedPreferences, rules), `lib/views` (pages),
`lib/items` (reusable widgets); named routes in `lib/app_routes.dart`. Only
`services/` imports `package:http` or Firestore; views and items call services.
Each layer has one subfolder per module: account and friends (`auth`, `user`,
`friends`), matches (`match`), stadiums (`stadium`), challenges (`challenge`),
tournaments (`tournament`, reference `docs/tournaments.md`), awards, settings.

## Rules to remember

- Do not add sample matches, tournaments or XP as if real; demo data only via
  `--dart-define=SAMPLE_DATA=true`.
- Firestore security rules are still test mode; do not claim the app is secure
  for release.
- UI follows `docs/design/kickoff_core_screens_prototypes.html` (flat, `#1A1A4E`,
  `#2D3A7A`, yellow controls, no gradients or patterns).
- Commits are authored only by the developer: no Claude co-author or session
  lines. Never push or force-push.
- Behavior or setup changes need updated tests and docs; run the narrowest
  relevant tests plus `flutter analyze`.
