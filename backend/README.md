# Kickoff API

Dart Shelf API for Kickoff's user, friend-request, direct-message,
gamification, and tournament features.
SQLite data is stored in `data/football_matches.sqlite` by default; the schema
is created and migrated by `lib/database.dart` when the server starts.

## Start

PowerShell:

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:JWT_SECRET = [Convert]::ToBase64String($bytes)
dart run bin/server.dart
```

`JWT_SECRET` is required and must be at least 32 characters. Set `PORT` or
`DB_PATH` before starting to change the listening port or database path. The
default database is `backend/data/football_matches.sqlite`, found from the
script's own location, so the server and `bin/seed.dart` use the same file from
any working directory; a compiled executable needs `DB_PATH`.

## Routes

- `POST /auth/register`, `POST /auth/login`
- `GET /me`, `GET /gamification`
- `GET /friends`, `DELETE /friends/{friendId}`
- `GET /friend-requests`, `POST /friend-requests`
- `POST /friend-requests/{requestId}/accept`
- `GET /friends/{friendId}/messages`, `POST /friends/{friendId}/messages`
- `GET /me/tournament-requests`, `GET /users/{userId}/profile`
- `GET /tournaments[?status=]`, `GET /tournaments/{id}`
- `POST /tournaments/{id}/join`, `DELETE /tournaments/{id}/join`
- `GET /tournaments/{id}/standings`, `GET /tournaments/{id}/bracket`
- `GET /tournaments/{id}/teams/{teamId}`,
  `POST /tournaments/{id}/teams/{teamId}/request`,
  `DELETE /tournaments/{id}/teams/{teamId}/members/{memberId}`
- `GET /tournaments/{id}/requests`, `PUT /tournaments/{id}/requests/{requestId}`

All routes other than registration and login require a bearer token.
Tournament request bodies, responses, errors and rules are documented in
[../docs/tournaments.md](../docs/tournaments.md).
Gamification state is stored in SQLite; XP and achievements are awarded by
defined server-side events and exposed through `GET /gamification`.

## Seed data

`bin/seed.dart` restores the seed accounts (password `Test1234!`), test
tournaments and the Champions League bracket from scratch, keeping other
accounts. Run it with `dart run bin/seed.dart` while the API is stopped, or
build it with `dart build cli` while it runs; see
[../docs/tournaments.md](../docs/tournaments.md#seed-data).

## Test

```powershell
dart analyze
dart test
```

On Windows, stop the API first: the running server locks
`.dart_tool/lib/sqlite3.dll`.
