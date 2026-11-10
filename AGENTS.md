# Kickoff project context

Source of truth for product rules, architecture and conventions. `CLAUDE.md`
and `.github/copilot-instructions.md` only add tool-specific notes. The
human-facing overview is `readme.md`.

## Product

Kickoff is a Flutter app (Android package `tn.esprit.kickoff`) for organising
football with friends: matches, stadium booking, challenges, tournaments,
friends and chat, awards. ESPRIT 5SAE2 mobile project.

## Architecture (Firebase + SQFlite, no backend)

There is **no server**. The Dart Shelf API that used to exist was removed; do
not reintroduce it or add a second source of truth.

- Every phone keeps a local SQFlite copy (`kickoff_local.db`) and shares data
  through Firebase Authentication and Cloud Firestore, so several phones show
  the same data. Lists read from Firestore and mirror into SQFlite so they open
  offline; writes need a connection.
- Business rules live in the app as pure Dart classes (`TournamentRules`,
  `TournamentFixtures`, `StadiumRules`). Keep them free of Flutter and
  Firestore so they stay unit-testable.
- A tournament and a stadium are each ONE Firestore document (teams, matches,
  bookings, reviews inside). Change them only through the store's `mutate`
  (a `runTransaction`); if the change callback throws, nothing is saved.
- Screens talk to small interfaces (`TournamentService`, `StadiumApi`,
  `StadiumDirectory`, `StadiumReviewSource`, `FriendsService`,
  `AccountService`, `ChallengeCloud`, `CloudSync`). `lib/main.dart` plugs in the
  Firestore versions when `FirebaseCloudSync.start()` succeeds, otherwise no-op
  versions (guest mode). Tests plug in in-memory fakes
  (`InMemoryTournamentStore`, `InMemoryStadiumStore`). Prefer adding a separate
  interface over adding methods to one that test fakes `implement`.
- `lib/api_client.dart`, `TournamentService` and the old HTTP stadium client
  remain only as base classes the Firestore versions implement, and for legacy
  tests. Do not add new HTTP calls to a Kickoff server.
- Numeric user id = `stableUserId(firebaseUid)` (FNV-1a), `UserAccount.id`.
  Stadium child ids are global: `stadiumId * 1000000 + n`.
- State management is plain `setState` and `ChangeNotifier` controllers; no
  Provider, Bloc or Riverpod.

### Firestore collections

`users`, `usernames`, `matches` (by join code), `friendRequests`,
`friendships`, `chats`, `challenges` (by join code), `tournaments`,
`tournamentNotifications`, `stadiums`, `stadiumOwners`, `meta/tournaments` and
`meta/stadiums` (id counters). Security rules are still **test mode** (expire
about 30 days after creation); writing real rules is pending.

### Local SQFlite tables

`users`, `session`, `matches`, `match_players`, `challenges`,
`challenge_participants`, `docs` (JSON mirror of Firestore documents through
`DocStore`). Schema version lives in `lib/local/local_database.dart`; add a
migration for any change.

## Implemented behavior

- **Account:** email and Google sign-in (Firebase Auth), unique username,
  profile edit, biometric lock, theme, guest mode. Profile CRUD is in SQFlite
  and synced to Firestore.
- **Friends and chat:** requests, accept, remove, private chat. Entry point:
  Profile, Friends, chat button on each friend row.
- **Matches:** create public or private, join by code or from the public list,
  calendar, weather. Search filters in `lib/matches/match_filter.dart`: part of
  day (morning, afternoon, evening, night), date, earliest start time.
- **Stadiums:** owner screens (pitches, hours, prices, block slots, pause,
  delete, booking inbox, auto-confirm) and player booking. Reviews: 1-5 stars
  and a comment, only from players who booked, one per player
  (`StadiumRules.addReview`, `stadium_reviews_sheet.dart`).
- **Challenges:** SQLite plus Firestore sync, sunrise/sunset row and travel
  time (`lib/travel/travel_service.dart`: Nominatim, OSRM car, OSM foot router;
  no API key; Nominatim needs a User-Agent header).
- **Tournaments:** create (league or knockout), join as captain, request to
  join, captain transfer, disband, fixtures, results, standings, bracket,
  stats, notifications. Reference: `docs/tournaments.md`. Known placeholders:
  knockout rounds after round one, player XP (0) and level (1); live match
  updates are not ported.
- **Awards:** local achievements and progress.
- Never add sample matches, tournaments or XP presented as real. Demo data comes
  only from `assets/sample_data.json` when started with
  `--dart-define=SAMPLE_DATA=true`.

## UI direction

- Core reference: `docs/design/kickoff_core_screens_prototypes.html` and
  `kickoff_match_flow_prototypes.html`. Flat layouts: solid `#1A1A4E`
  background, `#2D3A7A` panels, vivid blue cards, warm yellow controls, a single
  thicker bottom edge for chunky fills. No patterns, gradients, full outlines or
  offset shadows. Weights 500/600, icon-first navigation, 48-dp touch targets.
- Bottom bar has three items: calendar, ball (opens Challenge, Tournament,
  Match), profile (profile, settings, history).
- Keep the interface simple, playful and light on text. Sporcle Party and Kalak
  are mood references only; use original copy and artwork.
- Rewards and progress shown must come from stored data, never invented.

## Key files

- `lib/main.dart`: app setup, session restore, wiring of Firebase services.
- `lib/screens/kickoff_shell.dart`: three-item shell and module entry points.
- `lib/firebase/`: `CloudSync` and the Firebase implementation.
- `lib/local/`: SQFlite database, `DocStore`, session and local stores.
- `lib/auth/`, `lib/users/`, `lib/friends/`: accounts, profile, friends, chat.
- `lib/matches/`, `lib/screens/match/`: match model, controller, filters, flow.
- `lib/stadium/`: `stadium_module.dart` (models, owner screens),
  `stadium_rules.dart`, `stadium_store.dart`, `firestore_stadiums.dart`.
- `lib/challenges/`: database, repository, Firestore cloud, widgets.
- `lib/tournaments/`: models, screens, widgets; `cloud/` holds the rules,
  fixtures, store and Firestore service. Paths, sizes and copy live in
  `tournament_constants.dart`. Update `docs/tournaments.md` with any change.
- `lib/travel/`, `lib/daylight/`, `lib/weather/`, `lib/location/`, `lib/maps/`.
- `test/`: mirrors `lib/`. Cloud tests use in-memory stores and `MockClient`.
- `agents/`: role guides (brainstorm, code-writer, ux-designer, code-reviewer).
- `tools/phone.ps1`: runs the app on the USB test phone.

## Development and validation (PowerShell, from the project root)

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
.\tools\phone.ps1        # run on the USB phone (device 5TQ489FYO7S8EMSO)
```

- Firebase setup: package `tn.esprit.kickoff`; debug SHA-1 registered; Email and
  Google sign-in enabled; Firestore created; `android/app/google-services.json`
  (not tracked). Add a new SHA-1, then download the file again.
- `sqflite_common_ffi` (tests only) stops Gradle from packaging
  `libflutter.so`; `tools/phone.ps1` switches it off while running and restores
  `pubspec.*`. Do not commit those leftovers.
- Known red test: `TournamentService reports malformed responses` in
  `test/tournaments_test.dart` (legacy HTTP client; also red on main).
- When behavior or setup changes, update the related tests and docs, and run the
  narrowest relevant tests plus `flutter analyze`.

## Git rules

- Commits are authored by the developer only: no Claude co-author, trailer or
  session lines. Never push, force-push or amend pushed commits; give the
  commands instead.
- Work on branch `feat/firebase-only`. Do not commit `pubspec.*` leftovers or
  `google-services.json`.
