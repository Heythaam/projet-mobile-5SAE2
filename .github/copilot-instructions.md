# Copilot instructions for Kickoff

Read the root `AGENTS.md` for product, architecture, design direction, run
commands and git rules before making changes.

## Project conventions

- Kickoff has no backend. Data is SQFlite on the phone plus Firebase
  Authentication and Cloud Firestore. Do not add a server or HTTP calls to one.
- Keep business rules in pure Dart classes (`TournamentRules`,
  `TournamentFixtures`, `StadiumRules`) and talk to storage through the existing
  interfaces and stores. Change tournaments and stadiums only through
  `store.mutate` (one Firestore transaction).
- Screens depend on interfaces (`TournamentService`, `StadiumApi`,
  `StadiumDirectory`, `FriendsService`, `AccountService`, `ChallengeCloud`);
  add a new interface instead of widening one that test fakes implement.
- No API calls or database reads inside `build()`; load in `initState` or a
  controller.
- Never put secrets or real credentials in source, docs or logs.
  `google-services.json` is not tracked.
- Follow existing Dart formatting and Flutter lint rules. Prefer small,
  end-to-end changes, minimal diffs and existing error reporting (player-facing
  messages carry no technical detail).
- Keep Kickoff's visual language coherent: flat indigo `#1A1A4E` background,
  `#2D3A7A` panels, vivid blue cards, yellow controls with one thicker bottom
  edge, 48-dp touch targets. No patterns, gradients or outlined panels. Use
  original football-themed visuals.
- Only show rewards and progress that are really stored; no fake data.
- Update related tests and docs when behavior or setup changes.

## Validation

- `flutter analyze` and `flutter test` from the project root.
- Cloud logic is tested with `InMemoryTournamentStore`, `InMemoryStadiumStore`
  and `MockClient`; SQFlite through `sqflite_common_ffi`.
- For Android changes, `flutter build apk --debug`.
