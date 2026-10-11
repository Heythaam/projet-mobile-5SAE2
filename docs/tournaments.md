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
11. [Known limitations](#known-limitations)

## What players can do

| Who | Can |
|---|---|
| Any signed-in player | Browse, search and filter tournaments; view details, teams, standings and brackets; open any team's roster |
| Player without a team | Register a new team with a chosen name, or send a request to join an existing team |
| Captain | Answer join requests, view requesters' profiles, remove players, leave the tournament |
| Team member | See their team highlighted in the Teams tab and standings |

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

### Leaving

A captain can withdraw while the tournament is `upcoming`, the team has no
matches (byes included) and no accepted players. The team row is deleted,
freeing the spot and the name. The tournament JSON reports this as
`canLeave`; the app only offers **Leave tournament** when it is true.

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
  **Join now** / **View details**.
- **Detail** (`TournamentDetailScreen`): hero with status and progress, tabs by
  format, and a bottom area with **Join requests** (captains, with count) and
  the registration button (Join / Leave / Joined / Team member / Full /
  Registration closed). Four tabs scroll sideways rather than squeezing labels.
- **Join sheet**: team name field with live validation and counter; warns when
  a pending request will be cancelled; server errors stay in the sheet.
- **Leave / remove confirmation**: shared `ConfirmActionSheet` with a red
  confirm button and inline errors.
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
  refresh and after leaving the tournaments screens.

## API reference

All routes require `Authorization: Bearer <token>`. Errors are
`{"error": "message"}`; messages are written to be shown to players. JSON is
camelCase.

### Tournaments

| Method and path | Body | Success | Errors |
|---|---|---|---|
| `GET /tournaments[?status=]` | — | `{tournaments: [Tournament]}` (active, upcoming, finished, cancelled; max 100) | 400 invalid status |
| `GET /tournaments/:id` | — | `{tournament: TournamentDetail}` | 400, 404 |
| `POST /tournaments/:id/join` | `{"name": "Red Lions"}` | `{tournament}` | 400 name rules, 404, 409 already joined / on a team / closed / full / name taken |
| `DELETE /tournaments/:id/join` | — | `{tournament}` | 404, 409 not joined / started / has players / has matches |
| `GET /tournaments/:id/standings` | — | `{standings: [StandingRow]}` | 404 |
| `GET /tournaments/:id/bracket` | — | `{bracket: {rounds: [BracketRound]}}` | 404 |

`Tournament` fields: `id, name, description, format, status, startDate,
endDate, maxTeams, teamSize, currentTeams, location, prize, createdBy,
joined` (captain here), `canLeave`, `myTeamId` (team played for, as captain or
member), `pendingRequests` (for captains).

`TournamentDetail` adds `teams: [{id, name, players}]` and
`myRequests: [{teamId, status}]` (`pending`, `accepted`, `declined`,
`removed`, or `expired` after registration closes).

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
| `tournament_teams` | Registered teams | `captain_id` → users; `UNIQUE (tournament_id, captain_id)`; name unique per tournament ignoring ASCII case; `group_label` (nullable, e.g. `A`) |
| `join_requests` | Requests and memberships | `status`: `pending`, `accepted` (membership), `declined`, `cancelled`, `removed`; one `pending`/`accepted` row per (tournament, requester); index on (team, status) |
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
- SQLite cannot change `NOT NULL` or `CHECK` constraints, so
  `join_requests` and `tournament_matches` are rebuilt once
  (`_rebuildIfMissing`) when their schema lacks the newest status: rows are
  copied into a new table in one transaction and indexes recreated. Nothing
  references these tables, so the rebuild is safe.

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

Scripts in `backend/tool/` insert test data and skip anything that already
exists, so they can be rerun. `DB_PATH` overrides the database, as for the
server.

| Script | Inserts |
|---|---|
| `seed_tournaments.dart` | Champions Cup (knockout, active), City League (league, upcoming), Summer Cup (round robin, finished) |
| `seed_champions_league.dart` | Champions League (knockout, active, 8 teams): quarter-finals played (PSG through on penalties) and semi-finals scheduled. PSG, Liverpool, Juventus and AC Milan are captained by seed accounts `cl_psg`, `cl_liverpool`, `cl_juventus` and `cl_milan`, which have random passwords and cannot sign in |

Run from `backend/`:

```powershell
dart run tool/seed_tournaments.dart
```

While the API is running on Windows, `dart run` cannot replace the locked
`.dart_tool/lib/sqlite3.dll`. Either stop the API first or build the script
into another folder and run the executable:

```powershell
dart build cli -t tool/seed_champions_league.dart -o $env:TEMP\kickoff_seed
& "$env:TEMP\kickoff_seed\bundle\bin\seed_champions_league.exe"
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
│   ├── tournament_detail_screen.dart  tabs by format, join/leave/requests
│   ├── tournament_standings_screen.dart  standings view, per group
│   └── tournament_bracket_view.dart
└── widgets/
    ├── tournament_card.dart, requests_badge.dart (card badge, home banner)
    ├── standings_widget.dart, bracket_widget.dart
    ├── team_tile.dart, team_details_sheet.dart, player_profile_sheet.dart
    ├── join_team_sheet.dart, join_requests_sheet.dart
    ├── confirm_action_sheet.dart (leave, remove), sheet_frame.dart
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
flutter test                      # test/tournaments_test.dart, test/widget_test.dart
Set-Location backend
dart analyze
dart test                         # stop the API first on Windows
```

| File | Covers |
|---|---|
| `backend/test/tournaments_test.dart` | list, detail, join (names, capacity, status), leave, standings |
| `backend/test/join_requests_test.dart` | sending, answering, capacity, expiry, ownership |
| `backend/test/team_management_test.dart` | team details, removing players, pending totals, profile access, `removed` migration |
| `backend/test/bracket_test.dart` | bracket shape, winners, penalties, byes, positions, group tables, match constraints, `tournament_matches` migration |
| `test/tournaments_test.dart` | service parsing, every sheet and tab, format-based tabs, bracket drawing, 360 dp / 1.3× layouts, 48 dp targets |
| `test/widget_test.dart` | ball menu entry and home requests banner |

## Known limitations

- No admin routes to create tournaments, schedule matches, record results or
  assign groups; use SQLite (see above).
- No push notifications; captains see counts in the app.
- Members cannot leave a team, and captains with players cannot leave until
  they remove them.
- Any player can see profiles of everyone in a tournament they join or request
  to join (game stats only); team rosters with XP and streaks are visible to
  all signed-in players.
- Knockout draws without `winner_team_id` show no winner and leave the next
  slot TBD.
- On small phones a fourth tab can sit just past the edge of the tab bar.
- Name uniqueness ignores ASCII case only (`Équipe` and `équipe` both pass).
