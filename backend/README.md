# Kickoff API

Dart Shelf API for Kickoff's user, friend-request, and direct-message features.
SQLite data is stored in `data/football_matches.sqlite` by default.

## Start

PowerShell:

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:JWT_SECRET = [Convert]::ToBase64String($bytes)
dart run bin/server.dart
```

`JWT_SECRET` is required and must be at least 32 characters. Set `PORT` or
`DB_PATH` before starting to change the listening port or database path.

## Routes

- `POST /auth/register`, `POST /auth/login`
- `GET /me`
- `GET /friends`, `DELETE /friends/{friendId}`
- `GET /friend-requests`, `POST /friend-requests`
- `POST /friend-requests/{requestId}/accept`
- `GET /friends/{friendId}/messages`, `POST /friends/{friendId}/messages`

All routes other than registration and login require a bearer token.

## Test

```powershell
dart test
```
