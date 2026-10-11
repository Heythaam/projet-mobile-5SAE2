# Copilot instructions for Kickoff

Read the root `AGENTS.md` for product, architecture, design direction, and run
commands before making changes.

## Project conventions

- Keep the Flutter client (`lib/`) and Dart Shelf/SQLite API (`backend/`)
  responsibilities separate. Preserve typed models and use the existing
  `ApiClient` rather than issuing ad hoc HTTP requests from widgets.
- Server-owned data (accounts, friends, requests, chat, XP, achievements) must
  remain authoritative in the API/SQLite database.
- Preserve secure token handling and authenticated route behavior. Never put
  secrets or real credentials in source, docs, or logs.
- Follow existing Dart formatting and Flutter lint rules. Prefer small,
  end-to-end changes and retain existing error reporting.
- Keep Kickoff’s arcade-football visual language coherent across screens:
  indigo patterned surfaces, vivid blue panels, yellow controls, bold outlines,
  and clear hierarchy/touch targets. Use original football-themed visuals;
  external game apps are inspiration, not assets or templates to copy.
- Only show rewards/progress the backend really grants or records.
- Update directly related tests and docs when behavior or setup changes.

## Validation

- Flutter: `flutter analyze` and `flutter test` from the project root.
- Backend: `dart analyze` and `dart test` from `backend/`.
- For Android UI/network changes, build with
  `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8080`.
