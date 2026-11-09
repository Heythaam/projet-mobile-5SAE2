# Tournaments module

Players discover tournaments, register a team (or ask to join someone
else's), follow standings and knockout brackets, and captains manage their
roster. Everything shown comes from the API; the app holds no sample
tournaments, matches or results.

- Flutter code: `lib/tournaments/`
- API routes and rules: `backend/lib/app.dart`
- Schema and migrations: `backend/lib/database.dart`
- Team agents' guidelines: `agents/` (brainstorm, code-writer, ux-designer,
  code-reviewer)

## Contents

1. [What players can do](#what-players-can-do)
2. [Rules](#rules)
3. [Screens and flows](#screens-and-flows)
4. [API reference](#api-reference)
5. [Data model](#data-model)
6. [Bracket algorithm](#bracket-algorithm)
7. [Entering tournaments, matches and results](#entering-tournaments-matches-and-results)
8. [Seed data](#seed-data)
9. [Code layout](#code-layout)
10. [Testing](#testing)
11. [Troubleshooting](#troubleshooting)
12. [Known limitations](#known-limitations)
13. [Change history](#change-history)

## What players can do

| Who | Can |
|---|---|
| Any signed-in player | Browse, search and filter tournaments; view details, teams, standings and brackets; open any team's roster |
| Player without a team | Register a new team with a chosen name, or send a request to join an existing team |
| Captain | Answer join requests, view requesters' profiles, remove players, transfer captaincy, disband the team, leave the tournament |
| Team member | See their team highlighted in the Teams tab and standings, leave the team |

Tournaments open from the ball menu's **Tournament** option. Captains also
see waiting join requests on the home screen and on list cards.

## Rules

### Registration (creating a team)

- Only while the tournament is `upcoming` and has a free spot (`max_teams`).
  Status and capacity are checked inside the insert, so concurrent joins
  cannot overfill a tournament.
- One team per captain per tournament; players already on a team cannot
  create another.
- Team names are trimmed with spaces collapsed, 3–30 characters of letters
  (any language), numbers, spaces and `' . _ -`, with at least one letter or
  number, and unique per tournament ignoring ASCII case. The same rules live in
  `_teamName` (API) and `TeamName` (app) and must stay in sync.
- Creating a team cancels the player's pending join request; the join sheet
  warns about this first.
- Joining awards no XP.

### Leaving, transferring and disbanding

Everything here needs the tournament to be `upcoming`. Teams are never
deleted: a team that leaves keeps its row with `status` `left` (or
`disbanded`) and `left_at`, which frees its spot and name. Teams that left are
hidden from every list, count, table and roster.

- **Captain without players**: withdraws (`DELETE /join`) if the team has no
  matches (byes included). The team becomes `left`; pending requests to it
  become `cancelled`. Reported as `canLeave`; the app shows
  **Leave tournament**.
- **Captain with players**: cannot leave alone. The app shows
  **Transfer captaincy** and **Disband team** instead of Leave.
  - Transfer (`POST /transfer-captaincy`, `canTransfer`) hands the team to an
    accepted player and is allowed even with fixtures. The new captain's
    membership becomes `promoted` and the former captain gets an `accepted`
    membership, so they stay on the team as a player. Pending requests follow
    the team to the new captain.
  - Disband (`DELETE /join?disband=true`, `canDisband`) needs no matches. The
    team becomes `disbanded`; its players' memberships become `disbanded`
    and pending requests to it `cancelled`, so they can join or create
    another team. Without `disband=true`, a team with players is refused
    with 409.
  - Former players learn about it the next time they open the tournament:
    the detail JSON reports `teamDisbanded: true` until they tap the
    "Your team was disbanded by the captain" banner, which calls
    `DELETE /disband-notice` (stored in `join_requests.notice_seen_at`, so it
    is not shown again on any device). If that call fails the banner comes
    back with the error.
- **Player**: leaves their team (`DELETE /join`, `canLeave`, **Leave team**).
  The membership becomes `left`; the team and its fixtures stay, and the
  player may ask that team again.

### Join requests

- One pending request **or** one team per player per tournament (partial
  unique index on `join_requests`).
- Sending and answering require `upcoming` status. Unanswered requests are
  reported as `expired` once registration closes.
- Requests to a full team are refused; accepting re-checks capacity inside the
  update, so two answers at once cannot overfill a team.
- A team that declined or removed a player cannot be asked again by that
  player; other teams can.
- An accepted request **is** the membership. Team size (`team_size`, default
  5) counts the captain.

### Removing players

Only the team's captain, only before kickoff, never themselves. The request
becomes `removed`. Other captains get 404 (the team's existence is not
confirmed).

### Profiles

`GET /users/:id/profile` is visible to the player themselves, accepted
friends, and players who share a tournament (captain, member or pending
requester). Everyone else gets 404 so ids cannot be used to list players.
It returns game stats only: never email, message counts or achievement
progress.

### Standings and brackets

| Format | Detail tabs | Standings | Bracket |
|---|---|---|---|
| `league`, `round_robin` | About / Teams / Standings | One table | — |
| `knockout` | About / Teams / Bracket | — | Whole tournament |
| `groups_knockout` | About / Teams / Standings / Bracket | One table per group | Knockout stage only |

- Standings count only `played` matches with `stage = 'group'`: 3 points for
  a win, 1 for a draw, then goal difference, goals for, team name. Teams are
  ranked within their `group_label`; teams without a label share one table.
- The bracket uses `stage = 'knockout'` matches (see
  [Bracket algorithm](#bracket-algorithm)).
- Team stats and profile match history count every `played` match, both
  stages.

## Screens and flows

The UI uses the Kickoff palette from `AGENTS.md`; `agents/ux-designer.md`
supplies component sizes (12 dp radius, 16 dp padding, 48 dp minimum touch
targets), status meanings and flows. Every screen has loading, error (with
retry) and empty states, and is tested on a 360 dp phone at 1.3× text.

- **List** (`TournamentsListScreen`): search, filter chips (All, Active,
  Upcoming, Finished), skeleton cards, pull to refresh. Cards show dates,
  format, team count, status badge, a pending-requests badge for captains, and
  **Join now** / **View details**. The list reloads in place (no skeleton)
  whenever a screen above it closes (`RouteAware.didPopNext` through
  `appRouteObserver` in `lib/app_route_observer.dart`, registered in
  `MaterialApp.navigatorObservers`) and when the app returns to the
  foreground with the list on top.
- **Detail** (`TournamentDetailScreen`): hero with status and progress, tabs by
  format, and a bottom area with **Join requests** (captains, with count) and
  the registration button (Join / Leave tournament / Leave team / Joined /
  Team member / Full / Registration closed). Captains with players get
  **Transfer captaincy** and a quieter red **Disband team** instead. Four tabs
  scroll sideways rather than squeezing labels.
- **Join sheet**: team name field with live validation and counter; warns when
  a pending request will be cancelled; server errors stay in the sheet.
- **Leave / disband / remove confirmation**: shared `ConfirmActionSheet` with
  a red confirm button and inline errors. Disband names the team and how many
  players it removes.
- **Transfer sheet**: the team's players (not the captain) as a single-choice
  list; **Make {player} captain** stays disabled until one is picked, and
  server errors stay in the sheet, worded from the API's error `code`
  (team withdrawn, no longer captain, tournament started, player gone). The
  sheet cannot be swiped away while the request runs (a modal sheet's drag
  bypasses `PopScope`, so the sheet claims vertical drags meanwhile); the
  success snackbar comes from the detail screen.
- **Disbanded notice**: a former player of a disbanded team sees "Your team
  was disbanded by the captain" above the hero on the detail screen
  (`TeamDisbandedBanner`). Tapping anywhere on it hides it and records it as
  seen on the server.
- **Teams tab**: each team shows players `n/size`, the player's relation to it
  (Your team, Request pending ⏳, Declined, Removed, Request expired, Team full),
  **Request to join** when allowed, and **View team**.
- **Team sheet**: captain, players (level, XP, 🔥 streak), team stats, and
  remove buttons for the captain.
- **Join requests sheet**: pending requests with **View profile**, **Accept**
  and **Decline**; errors stay on the row.
- **Profile sheet**: rank, level, XP, streaks, unlocked achievements and up to
  10 recent matches.
- **Bracket tab**: one column per round (Round of 16 … Final), connector lines,
  winners in yellow with a trophy, `TBD` for unknown teams, `Bye` for byes,
  and a status line (date, Full time, Won on penalties, Advances, Cancelled,
  Not scheduled). Scrolls in both directions.
- **Home**: banner "N join requests waiting" for captains, refreshed on pull to
  refresh and whenever Home becomes visible again: a screen above the shell
  closes (`appRouteObserver`), the Home tab is selected again, or the app
  resumes with Home on top. Only the latest load updates the banner.

## API reference

All routes require `Authorization: Bearer <token>`. Errors are
`{"error": "message"}`, plus `"code"` where the app reacts to a specific
reason (transfer: `team_withdrawn`, `not_captain`, `transfer_closed`,
`player_not_on_team`); messages are written to be shown to players. JSON is
camelCase.

### Tournaments

| Method and path | Body | Success | Errors |
|---|---|---|---|
| `GET /tournaments[?status=]` | — | `{tournaments: [Tournament]}` (active, upcoming, finished, cancelled; max 100) | 400 invalid status |
| `GET /tournaments/:id` | — | `{tournament: TournamentDetail}` | 400, 404 |
| `POST /tournaments/:id/join` | `{"name": "Red Lions"}` | `{tournament}` | 400 name rules, 404, 409 already joined / on a team / closed / full / name taken |
| `DELETE /tournaments/:id/join[?disband=true]` | — | `{tournament}` | 404, 409 not joined / started / has players (without `disband`) / has matches |
| `POST /tournaments/:id/transfer-captaincy` | `{"newCaptainId": 12}` | `{tournament}` | 400 missing id / yourself, 403 `not_captain`, 404 `player_not_on_team`, 409 `team_withdrawn` / `transfer_closed` (a withdrawn team is reported first) |
| `DELETE /tournaments/:id/disband-notice` | — | 204 | 404 |
| `GET /tournaments/:id/standings` | — | `{standings: [StandingRow]}` | 404 |
| `GET /tournaments/:id/bracket` | — | `{bracket: {rounds: [BracketRound]}}` | 404 |

`Tournament` fields: `id, name, description, format, status, startDate,
endDate, maxTeams, teamSize, currentTeams, location, prize, createdBy,
joined` (captain here), `canLeave`, `canTransfer`, `canDisband` (see
Leaving), `myTeamId` (team played for, as captain or member),
`pendingRequests` (for captains).

`TournamentDetail` adds `teams: [{id, name, players}]` and
`myRequests: [{teamId, status}]` (`pending`, `accepted`, `declined`,
`removed`, or `expired` after registration closes; `cancelled`, `left`,
`promoted` and `disbanded` rows are omitted) and `teamDisbanded`.

`StandingRow`: `position, teamId, teamName, played, wins, draws, losses,
goalsFor, goalsAgainst, goalDifference, points, isUserTeam, group`.

### Teams and join requests

| Method and path | Body | Success | Errors |
|---|---|---|---|
| `GET /tournaments/:id/teams/:teamId` | — | `{team: TeamDetails}` | 400, 404 |
| `POST /tournaments/:id/teams/:teamId/request` | — | 201 `{tournament}` | 404, 409 closed / on a team / pending elsewhere / declined / removed / full |
| `GET /tournaments/:id/requests` | — | `{requests: [JoinRequest]}` (pending, oldest first) | 403 not a captain, 404 |
| `PUT /tournaments/:id/requests/:requestId` | `{"status": "accepted"}` or `"declined"` | `{request: JoinRequest}` | 400, 404 not your team's, 409 answered / closed / full / player has a team |
| `DELETE /tournaments/:id/teams/:teamId/members/:memberId` | — | `{team: TeamDetails}` | 400 removing yourself, 404, 409 started |

`TeamDetails`: `id, name, captainId, captainName, teamSize, canManage,
players: [{id, username, xp, level, currentStreak, isCaptain}], stats:
{players, totalXp, averageLevel, played, wins, draws, losses, goalsFor,
goalsAgainst, points}`.

`JoinRequest`: `id, teamId, teamName, requesterId, requesterName, status,
createdAt` (SQLite UTC, `YYYY-MM-DD HH:MM:SS`).

### Players

| Method and path | Success | Errors |
|---|---|---|
| `GET /me/tournament-requests` | `{pendingRequests}`: total waiting for the captain in open tournaments | — |
| `GET /users/:id/profile` | `{profile: {id, username, xp, level, rank, currentStreak, bestStreak, achievements: [{code, title, icon, unlockedAt}], recentMatches: [{tournamentName, teamName, opponentName, goalsFor, goalsAgainst, result, playedAt}]}}` | 400, 404 (also when not allowed) |

### Bracket

```json
{"bracket": {"rounds": [
  {"round": 1, "roundsFromEnd": 1, "matches": [
    {"id": 12, "position": 1,
     "home": {"id": 3, "name": "PSG"}, "away": {"id": 5, "name": "Liverpool"},
     "homeScore": 1, "awayScore": 1, "status": "played", "winnerId": 3,
     "scheduledAt": null}]},
  {"round": 2, "roundsFromEnd": 0, "matches": [
    {"id": null, "position": 1, "home": {"id": 3, "name": "PSG"},
     "away": null, "homeScore": null, "awayScore": null,
     "status": "pending", "winnerId": null, "scheduledAt": null}]}]}}
```

- `roundsFromEnd`: 0 is the final; the app names rounds (Final, Semi-finals,
  Quarter-finals, Round of 16, otherwise "Round N").
- `status`: `scheduled`, `played`, `cancelled`, `bye`, or `pending` for a slot
  with no match row yet (`id` is null).
- `home`/`away` are null while the team is to be determined (shown as TBD).
- `rounds` is empty until the first knockout match exists.

## Data model

| Table | Purpose | Key columns and constraints |
|---|---|---|
| `tournaments` | Tournament settings | `format` (`knockout`, `league`, `groups_knockout`, `round_robin`), `status` (`upcoming`, `active`, `finished`, `cancelled`), `start_date ≤ end_date`, `max_teams ≥ 2`, `team_size ≥ 1` (default 5, captain included), `created_by` → users (set null) |
| `tournament_teams` | Registered teams, including ones that left | `captain_id` → users; `status` (`active`, `left`, `disbanded`) with `left_at` set exactly when not `active`; among active teams one per captain and names unique per tournament ignoring ASCII case (partial unique indexes); `group_label` (nullable, e.g. `A`) |
| `join_requests` | Requests and memberships | `status`: `pending`, `accepted` (membership), `declined`, `cancelled`, `removed`, `left` (player left), `promoted` (player became captain), `disbanded` (the captain disbanded the player's team; `notice_seen_at` once seen); one `pending`/`accepted` row per (tournament, requester); index on (team, status) |
| `tournament_matches` | Fixtures and results | `stage` (`group` default, `knockout`), `round ≥ 1`, `bracket_position ≥ 1` (unique per tournament, stage and round), scores ≥ 0, `winner_team_id` (one of the two teams), `status` (`scheduled`, `played`, `cancelled`, `bye`) |

Match constraints, enforced by SQLite:

- Group matches name both teams; knockout matches may leave a team null (TBD).
- `played` needs both teams and both scores.
- `bye` is knockout-only, with the advancing team as home and no away team.
- Home and away differ when both are set.

### Migrations

`AppDatabase` migrates on start, so restarting the API is enough:

- New columns use `ALTER TABLE … ADD COLUMN` when missing (`team_size`,
  `group_label`).
- SQLite cannot change `NOT NULL`, `CHECK` or inline `UNIQUE` constraints,
  so `tournament_teams`, `join_requests` and `tournament_matches` are rebuilt
  once (`_rebuildIfMissing`) when their schema lacks the newest status: rows
  are copied into a new table in one transaction and indexes recreated.
  Foreign keys are switched off during the rebuild so dropping
  `tournament_teams` does not cascade into matches and requests, and
  `PRAGMA foreign_key_check` must pass before the commit.

Migrations are covered by tests that start from the older schemas.

## Bracket algorithm

`GET /tournaments/:id/bracket` (`_tournamentBracket`) always returns the full
shape of the knockout tree:

1. Knockout rows are grouped by `round`. The lowest round is the first.
2. The first round gets `nextPowerOfTwo(slots needed)` slots; each later round
   has half as many, down to the final. Extra rows beyond that shape are kept,
   never dropped.
3. Rows sit at their `bracket_position`; rows without one fill the first free
   slots in id order.
4. Slots without a row become `pending` placeholders. A placeholder's teams are
   the winners of the two slots that feed it (slots `2p-1` and `2p` of the
   previous round), or null.
5. Winners: in a played match the higher score; on a draw, `winner_team_id`
   (penalties), otherwise none; in a `bye`, the home team.

The app (`BracketWidget`) draws one column per round and centres each match
between the two matches that feed it. Card heights are computed from the
text scale so large text never clips.

## Entering tournaments, matches and results

There are no admin routes yet: tournaments, matches, results and group labels
are inserted directly in SQLite. The API needs no restart for new rows; it
reads the database on every request. Examples:

```sql
-- A knockout quarter-final, played, decided on penalties.
INSERT INTO tournament_matches (tournament_id, stage, round, bracket_position,
  home_team_id, away_team_id, home_score, away_score, winner_team_id, status)
VALUES (4, 'knockout', 1, 3, 9, 10, 1, 1, 9, 'played');

-- A bye: team 11 advances from slot 4 of round 1.
INSERT INTO tournament_matches (tournament_id, stage, round, bracket_position,
  home_team_id, status)
VALUES (4, 'knockout', 1, 4, 11, 'bye');

-- A league or group-stage result (stage defaults to 'group').
INSERT INTO tournament_matches (tournament_id, home_team_id, away_team_id,
  home_score, away_score, status)
VALUES (2, 1, 2, 3, 1, 'played');

-- Put teams into groups for a groups + knockout tournament.
UPDATE tournament_teams SET group_label = 'A' WHERE id IN (1, 2);

-- Record a result for a scheduled match.
UPDATE tournament_matches
SET home_score = 2, away_score = 0, status = 'played'
WHERE id = 5;
```

Never add sample tournaments or results on the client.

## Seed data

`backend/bin/seed.dart` restores the test data from scratch. Each run deletes
the seed accounts (emails `@kickoff.test`, plus `@seed.kickoff.invalid`
accounts from older seed scripts) and the four seed tournaments by name, whose
teams, matches and requests cascade, then inserts everything again in one
transaction, checks the row counts and prints what it inserted. Other accounts
are kept; if one of them already uses a seed username, the script stops
without changing anything. Like the server, it uses
`backend/data/football_matches.sqlite` (found from the script's own location,
whatever the working directory) unless `DB_PATH` is set.

| Data | Contents |
|---|---|
| Users | `alice`, `bob`, `carlos`, `diana`, `cl_psg`, `cl_liv`, `cl_juve`, `cl_milan`, emails `<username>@kickoff.test`, password `Test1234!` |
| Tournaments | Champions Cup (knockout, active), City League (league, upcoming), Summer Cup (round robin, finished), Champions League (knockout, active) |
| Champions League | 8 teams (Real Madrid/alice, Barcelona/bob, Manchester City/carlos, Bayern Munich/diana, PSG/cl_psg, Liverpool/cl_liv, Juventus/cl_juve, AC Milan/cl_milan); quarter-finals played (PSG through on penalties) and semi-finals scheduled |

Run from `backend/` (or from anywhere, with the script's path):

```powershell
dart run bin/seed.dart
```

While the API is running on Windows, `dart run` cannot replace the locked
`.dart_tool/lib/sqlite3.dll`. Either stop the API first or build the script
into another folder and run the executable. A compiled executable cannot
find the backend folder from its own location, so it refuses to run without
`DB_PATH`:

```powershell
dart build cli -t bin/seed.dart -o $env:TEMP\kickoff_seed
$env:DB_PATH = (Resolve-Path data\football_matches.sqlite).Path
& "$env:TEMP\kickoff_seed\bundle\bin\seed.exe"
Remove-Item Env:DB_PATH
```

The same lock affects `dart test`; stop the API before running backend tests.

## Code layout

```
lib/tournaments/
├── tournament_constants.dart   endpoints, colours, sizes, all user-facing copy
├── models/
│   ├── tournament.dart         Tournament, teams, standings, requests, TeamName
│   ├── team_details.dart       roster and team stats
│   ├── player_profile.dart     public profile and match history
│   └── bracket.dart            rounds and bracket matches
├── services/
│   └── tournament_service.dart every API call, with timeout and friendly errors
├── screens/
│   ├── tournaments_list_screen.dart
│   ├── tournament_detail_screen.dart  tabs by format, join/leave/transfer/
│   │                                  disband/requests
│   ├── tournament_standings_screen.dart  standings view, per group
│   └── tournament_bracket_view.dart
└── widgets/
    ├── tournament_card.dart, requests_badge.dart (card badge, home banner)
    ├── standings_widget.dart, bracket_widget.dart
    ├── team_tile.dart, team_details_sheet.dart, player_profile_sheet.dart
    ├── join_team_sheet.dart, join_requests_sheet.dart
    ├── confirm_action_sheet.dart (leave, disband, remove), sheet_frame.dart
    ├── transfer_captaincy_sheet.dart, team_disbanded_banner.dart
    └── tournament_states.dart (header, loading, skeleton, error, empty)
```

Conventions (`agents/code-writer.md`): screens call the service, never HTTP;
every service call goes through `_guard`, which adds a 15 s timeout and turns
network, timeout and parsing failures into `TournamentException` with a
friendly message; constants are UPPER_SNAKE in `tournament_constants.dart`;
every model has `fromJson`.

`lib/achievement_icons.dart` maps achievement icon names for both the
profile screen and the tournaments profile sheet.

## Testing

```powershell
flutter analyze
flutter test                      # every file in test/
Set-Location backend
dart analyze
dart test                         # stop the API first on Windows
```

| File | Covers |
|---|---|
| `backend/test/tournaments_test.dart` | list, detail, join (names, capacity, status), leave and its history row, standings |
| `backend/test/join_requests_test.dart` | sending, answering, capacity, expiry, ownership |
| `backend/test/team_management_test.dart` | team details, removing players, pending totals, profile access, `removed` migration |
| `backend/test/captaincy_test.dart` | transfer and its error codes, disband and its notice, player leave, `tournament_teams` migration |
| `backend/test/bracket_test.dart` | bracket shape, winners, penalties, byes, positions, group tables, match constraints, `tournament_matches` migration |
| `test/tournaments_test.dart` | service parsing, every sheet and tab, format-based tabs, bracket drawing, transfer / disband / leave-team flows, transfer error codes, swipe guard, disbanded notice, list refresh on return and resume, 360 dp / 1.3× layouts, 48 dp targets |
| `test/widget_test.dart` | ball menu entry, home requests banner and its refresh (back from any screen, Home tab selected again, app resumed) |
| `test/api_client_test.dart` | session restore: 401 and 404 clear the token, other errors keep it |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| A new screen, banner or button is missing after restarting the app | The installed APK is older than the code; restarting relaunches the old build | Rebuild and reinstall (`flutter build apk --debug`, then `adb install -r`), or use `flutter run` |
| "Could not restore your session" with only **Try again** | The saved token belongs to an account that no longer exists, for example after reseeding | Fixed: `ApiClient.restoreSession` treats 404 like 401, clears the token and shows sign-in |
| Database changes don't show in the app | The API and the seed use different files: a `DB_PATH` set in one shell but not the other, or an API started before the path fix from the repo root (it used `<root>/data/`) | Restart the API; without `DB_PATH` both scripts now use `backend/data/football_matches.sqlite` from any working directory |
| `dart test` or `dart run bin/seed.dart` fails with `PathAccessException` on `sqlite3.dll` | The running API locks `backend/.dart_tool/lib/sqlite3.dll` on Windows | Stop the API, run from a copy of `backend/` (`lib`, `bin`, `test`, pubspec files), or build the script with `dart build cli` |
| A new status or column is missing from the database | The API was not restarted | Restart the API; `AppDatabase` migrates on start |

To check the disband notice end to end against a running API: seed, have
alice create a team in City League, have bob ask to join and alice accept,
call `DELETE /tournaments/:id/join?disband=true` as alice, then
`GET /tournaments/:id` as bob. The response carries `"teamDisbanded":true`
until bob calls `DELETE /tournaments/:id/disband-notice`.

## Known limitations

- No admin routes to create tournaments, schedule matches, record results or
  assign groups; use SQLite (see above).
- No push notifications; captains see counts in the app, and players of a
  disbanded team see a banner only when they open that tournament.
- Once a tournament starts, nobody can leave, transfer or disband.
- Any player can see profiles of everyone in a tournament they join or request
  to join (game stats only); team rosters with XP and streaks are visible to
  all signed-in players.
- Knockout draws without `winner_team_id` show no winner and leave the next
  slot TBD.
- On small phones a fourth tab can sit just past the edge of the tab bar.
- Name uniqueness ignores ASCII case only (`Équipe` and `équipe` both pass).
- A transfer request sent for a team that was then withdrawn could, in
  theory, move captaincy of a new team the same captain created afterwards,
  if the chosen player is also on it.
- The transfer success snackbar shows briefly behind the sheet as it closes.
- Closing any popup over the home shell (for example Settings) also refreshes
  the home banner: one small extra request.
- Error codes are written twice, in `TournamentErrorCodes` (app) and in the
  API; keep them in sync.
- Players who leave a team drop out of profile visibility for that
  tournament, and their past matches with that team no longer appear in their
  profile.

## Change history

Newest first. Each round ran as brainstorm, then implementation, then code
review, following `agents/`; critical and high review findings were fixed
before the round closed.

### 2026-10-12: disbanded notice missing on the device

- **Reported**: the "Your team was disbanded by the captain" banner did not
  show after a full restart.
- **Checked**: the API returned `"teamDisbanded":true` for the disbanded
  player; `Tournament.fromJson` parses it; the detail screen shows
  `TeamDisbandedBanner` when it is true and not dismissed; temporary debug
  prints confirmed the value reached the widget.
- **Cause**: the APK on the device was built before the banner code was
  written, so restarting relaunched the old build. After rebuilding, the
  banner showed, and dismissing it recorded `notice_seen_at`.
- **Also fixed**: after reseeding, a saved token pointed at a deleted
  account; `GET /me` answered 404 and the app stayed on a retry screen that
  could never succeed. `restoreSession` now clears the token on 404 as on 401
  (`test/api_client_test.dart`).
- **Found**: the API had been started from the repo root and used
  `<root>/data/football_matches.sqlite` instead of `backend/data/`. Fixed
  afterwards: `bin/server.dart` and `bin/seed.dart` resolve the default from
  their own location (`databasePath()` in `backend/lib/database_path.dart`),
  and compiled executables require `DB_PATH`. The stray root `data/` folder
  was removed.

### 2026-10-12: review follow-ups

| Issue | Root cause | Fix |
|---|---|---|
| A transfer after the team was withdrawn said the tournament had started | Checks ran before the transaction, and any failure of the captain update was reported as "closed" | All checks run under the write lock; errors carry a `code` (`team_withdrawn`, `not_captain`, `transfer_closed`, `player_not_on_team`), a withdrawn team reported first; the app words each code from `TournamentStrings` |
| The transfer sheet could be swiped closed mid-request, losing the success message | A modal sheet's drag calls `Navigator.pop` directly and skips `PopScope`; `isDismissible` only covers barrier taps | While a request runs the sheet claims vertical drags itself (swiping works again after); the detail screen shows the success snackbar |
| Players of a disbanded team got no notice | Disbanding turned memberships into `cancelled`, indistinguishable from withdrawn requests | Memberships become `disbanded`; detail JSON adds `teamDisbanded`; `DELETE /disband-notice` stores `notice_seen_at`, so the banner shows once across devices |
| The home banner refreshed only after leaving the tournaments screens | The shell reloaded the count only after that one push | The route observer moved to `lib/app_route_observer.dart`; the shell is `RouteAware` and refreshes on `didPopNext`, when the Home tab is selected again, and on app resume; only the latest load applies |

### 2026-10-12: captaincy, team history and list refresh

| Issue | Fix |
|---|---|
| A captain with players could not leave | `POST /transfer-captaincy` hands the team to an accepted player (the old captain stays as a player); `DELETE /join?disband=true` withdraws the team and frees its players; players can leave their team themselves, so a former captain can then leave |
| Leaving deleted the team row | `tournament_teams.status` (`active`, `left`, `disbanded`) and `left_at`; the inline `UNIQUE (tournament_id, captain_id)` and the name index became partial unique indexes over active teams, so captains can rejoin and names can be reused; every team query filters `status = 'active'`; the table rebuild runs with foreign keys off so matches and requests are not cascaded away |
| The list's pending-requests badge refreshed only on pull to refresh | The list is `RouteAware` and reloads in place whenever a screen above it closes, and when the app resumes with the list on top |

UI added in this round: **Transfer captaincy** (picker sheet; its confirm
button stays greyed out until a player is chosen), a quieter red
**Disband team** with a confirmation naming how many players are removed,
and **Leave team** for players. Tournament JSON gained `canTransfer` and
`canDisband`; `join_requests` gained the `left` and `promoted` statuses.
