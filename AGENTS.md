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
- Tournaments: the ball menu's Tournament option opens a list (search, status
  filter, skeleton loading) and detail (tabs by format, join through a
  team-name sheet, leave through a confirmation sheet while registration is
  open). Full reference: `docs/tournaments.md`. Authenticated routes:
  `GET /tournaments[?status=]`, `GET /tournaments/:id` (adds `teams`),
  `POST /tournaments/:id/join` (body `{"name"}`),
  `DELETE /tournaments/:id/join` (leave; only while `upcoming` and before the
  team has matches, deleting the team row; tournament JSON reports this as
  `canLeave`, which the app uses to offer Leave) and
  `GET /tournaments/:id/standings`, returning camelCase JSON as
  `{tournaments}`, `{tournament}` and `{standings}`.
  Tables: `tournaments`, `tournament_teams` (one entry per captain, with a
  captain-chosen name unique per tournament, ignoring ASCII case) and
  `tournament_matches`. Team names are trimmed with spaces collapsed, 3-30
  characters of letters, numbers, spaces and `' . _ -`; the rules live in
  `_teamName` (API) and `TeamName` (app) and must stay in sync. Joining
  requires `upcoming` status and a
  free spot (checked inside the insert); standings are computed from `played`
  matches (3/1/0 points, then goal difference, goals for, name). There is no
  create-tournament or record-result route yet, so tournaments and results are
  inserted directly in SQLite. Joining awards no XP. Do not add sample
  tournaments on the client.
- Team join requests: instead of captaining a team, a player can ask to join
  one from the Teams tab; the captain answers from a Join requests sheet on the
  detail screen. Routes: `POST /tournaments/:id/teams/:teamId/request`,
  `GET /tournaments/:id/requests` (captain's pending requests) and
  `PUT /tournaments/:id/requests/:requestId` (body `{"status"}`, `accepted` or
  `declined`). Table `join_requests` (`pending`, `accepted`, `declined`,
  `cancelled`); an accepted request is the team membership, and a partial
  unique index allows one pending or accepted request per user and
  tournament. `tournaments.team_size` (default 5, captain included) caps
  players. Requests and answers need `upcoming` status; pending requests are
  reported as `expired` afterwards. A declined team cannot be asked again,
  creating your own team cancels your pending request, members cannot create a
  team, and captains with players cannot leave. Tournament JSON adds
  `teamSize`, `myTeamId`, `pendingRequests`, `myRequests` and `teams[].players`.
  There is no push notification yet; captains see pending counts on the detail
  screen, on list cards and in a home banner (`GET /me/tournament-requests`
  returns the total for open tournaments).
- Detail tabs follow the format: `league`/`round_robin` show Standings,
  `knockout` shows Bracket, `groups_knockout` shows both (Standings has one
  table per `tournament_teams.group_label`, counting only `stage = 'group'`
  played matches; Bracket shows the knockout stage).
  `GET /tournaments/:id/bracket` returns `{bracket: {rounds}}`: each round has
  `round`, `roundsFromEnd` (0 = final; the app names rounds) and every slot as
  a match (`id`, `position`, `home`/`away` `{id, name}` or null for TBD,
  scores, `status`, `winnerId`, `scheduledAt`). The first round has a
  power-of-two number of slots; missing slots and later rounds are `pending`
  placeholders filled with the known winners feeding them. Knockout rows in
  `tournament_matches` use `stage = 'knockout'`, `bracket_position`, may leave a
  team null, use status `bye` (home team advances) and `winner_team_id` for
  draws decided on penalties. Matches are still inserted directly in SQLite.
- Team management: Teams tab tiles open a team sheet
  (`GET /tournaments/:id/teams/:teamId`: captain, players with XP, level and
  streak, and stats from played matches). Its captain can remove players
  before kickoff (`DELETE /tournaments/:id/teams/:teamId/members/:memberId`),
  which marks the request `removed`; removed players can join another team
  but not ask that one again. The join sheet warns when creating a team will
  cancel a pending request. Captains open a requester's profile from the
  requests sheet: `GET /users/:id/profile` returns XP, level, rank, streaks,
  unlocked achievements and recent played matches, only for yourself, friends
  and players who share a tournament with you (404 otherwise). Match history
  is limited to `tournament_matches`; never fill it with sample data.
- Tournament screens use the Kickoff palette; `agents/ux-designer.md`
  supplies component sizes, status meanings and flows, not its green palette.
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
- `lib/tournaments/`: tournament models, service, screens and widgets; follows
  `agents/code-writer.md`. Paths, sizes and copy live in
  `tournament_constants.dart`.
- `docs/tournaments.md`: tournaments module reference (rules, API, data model,
  bracket algorithm, SQL examples, seed data). Update it with any tournament
  change.
- `lib/achievement_icons.dart`: achievement icon names shared by profile views.
- `backend/lib/app.dart`: Shelf routes and handlers.
- `backend/lib/database.dart`: SQLite schema and migrations.
- `backend/lib/gamification.dart`: XP and achievement rules.
- `backend/test/tournaments_test.dart`, `join_requests_test.dart`,
  `team_management_test.dart`, `bracket_test.dart`: tournament routes, rules
  and schema migrations.
- `backend/bin/seed.dart`: restores seed accounts, test tournaments and the
  Champions League bracket from scratch.
- `android/build.gradle.kts`: uses Flutter's NDK when installed, otherwise the
  newest installed NDK, for the app and every plugin.
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

On Windows the running API locks `backend/.dart_tool/lib/sqlite3.dll`, so
`dart test` and `dart run bin/seed.dart` fail while it runs. Stop the API, run the
tests from a copy of `backend/lib`, `backend/test` and the pubspec files, or
build tools with `dart build cli`.

When changing UI or API behavior, update the relevant tests and documentation.
Run the narrowest relevant tests plus `flutter analyze` or `dart analyze`; build
the Android APK when validating Android-specific UI or networking.
