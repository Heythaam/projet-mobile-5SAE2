# Architecture adjustment plan

Goal: make Kickoff follow the architecture taught in class and used in the
professor's reference repository (`FlutterSAE_2627`), without changing what the
app does.

## Status

Phases 1 to 4 are done: files moved, mixed files split, behavior aligned
(routes map, validated form, HTTP constants, timeout, `FutureBuilder` on the
daylight row), tests moved to mirror `lib/`, docs updated, and the stadium owner
screens split into one file per screen (shared widgets in
`items/stadium/stadium_widgets.dart`). Not done: `FutureBuilder` on the big list
screens.

## 1. The reference architecture

The professor's `lib/` has five layer folders and a `main.dart` with a named
`routes:` map:

| Folder | Role |
|---|---|
| `entities/` | Plain classes with `toJson` and `fromJson` |
| `bd/` | SQFlite only: open the database, create tables, CRUD |
| `services/` | Everything that talks outside a screen: `http` calls, `shared_preferences`, and in our case Firestore |
| `views/` | One full page per file |
| `items/` | Small reusable widgets used by the views (a card, a row, a drawer) |

Rules that follow from the lessons:

1. Only `services/` imports `package:http` or Firestore. `views/` and `items/`
   call a service, never the network or the database.
2. `bd/` is the only place that opens SQFlite.
3. `entities/` has no Flutter widgets and no I/O.
4. Forms use `Form` + `GlobalKey<FormState>` + `TextFormField` + `validator`
   and call `validate()` before submitting (lesson 4).
5. Navigation uses the `routes:` map and `Navigator.pushNamed` for the main
   screens (lesson 4), `push` with arguments for detail screens.
6. HTTP: `Uri.parse`, headers, `json.encode` / `json.decode`, status check,
   try/catch, timeout (lesson 6). Base URLs live in one constants file.
7. Lists use `ListView.builder` / `GridView.builder`; async screens may use
   `FutureBuilder` (lessons 3 and 6).

## 2. Target layout (subfolder per module)

```
lib/
  main.dart                        routes map, app setup
  app_route_observer.dart
  entities/   user/ match/ stadium/ challenge/ tournament/
  bd/         local database, DocStore, session, user and match stores, challenge db
  services/   auth/ friends/ match/ stadium/ challenge/ tournament/ user/
              firebase/ location/ maps/ security/ settings/ awards/
  views/      auth/ home/ user/ friends/ match/ stadium/ challenge/
              tournament/ settings/ maps/
  items/      match/ stadium/ challenge/ tournament/ user/ awards/
```

## 3. File map

### entities/
| From | To |
|---|---|
| `models.dart` | `entities/user/models.dart` |
| `users/builtin_countries.dart`, `users/dial_codes.dart` | `entities/user/` |
| `matches/football_match.dart`, `matches/match_filter.dart` | `entities/match/` |
| `screens/match/match_mock_data.dart` | `entities/match/` |
| `matches/stadium_directory.dart` (models: `RealStadium`, `RealPitch`, `FreeSlot`, `StadiumReview`, `StadiumReviewSet`) | `entities/stadium/real_stadium.dart` (split) |
| `stadium/stadium_module.dart` (models: `Stadium`, `StadiumDraft`, `Pitch`, `BookingInbox`, `DayAvailability`, ...) | `entities/stadium/stadium.dart` (split) |
| `challenges/models/*` | `entities/challenge/` |
| `tournaments/models/*` | `entities/tournament/` |

### bd/
| From | To |
|---|---|
| `local/local_database.dart`, `local/doc_store.dart`, `local/session_store.dart`, `local/user_local_store.dart`, `local/match_local_store.dart` | `bd/` |
| `core/local_database.dart` | `bd/core_database.dart` (renamed, name clash) |
| `challenges/database/challenge_database.dart` | `bd/` |

### services/
| From | To |
|---|---|
| `api_client.dart` | `services/api_client.dart` (+ timeout) |
| `auth/*` | `services/auth/` |
| `friends/friends_service.dart`, `friends/firestore_friends_service.dart` | `services/friends/` |
| `firebase/*` | `services/firebase/` |
| `matches/match_controller.dart`, `matches/match_repository.dart` | `services/match/` |
| `matches/stadium_directory.dart` (interface, HTTP client, exception) | `services/stadium/stadium_directory.dart` (split) |
| `stadium/stadium_module.dart` (`StadiumApi`, `HttpStadiumApi`) | `services/stadium/stadium_api.dart` (split) |
| `stadium/stadium_rules.dart`, `stadium_store.dart`, `firestore_stadiums.dart` | `services/stadium/` |
| `challenges/repository/*` | `services/challenge/` |
| `daylight/daylight_service.dart` (service part) | `services/challenge/daylight_service.dart` (split) |
| `travel/travel_service.dart` (service part) | `services/challenge/travel_service.dart` (split) |
| `weather/weather_service.dart` | `services/match/weather_service.dart` |
| `tournaments/cloud/*`, `tournaments/services/tournament_service.dart` | `services/tournament/` |
| `users/country_service.dart`, `users/user_profile_controller.dart` | `services/user/` |
| `location/player_location.dart` | `services/location/` |
| `maps/map_picker_screen.dart` (place lookup part) | `services/maps/place_service.dart` (split) |
| `security/app_lock.dart` (logic), `settings/theme_preference.dart` | `services/security/`, `services/settings/` |
| `awards/local_awards.dart` | `services/awards/` |
| `sample_data/sample_data.dart` | `services/sample_data.dart` |

### views/
| From | To |
|---|---|
| `auth_screen.dart`, `users/choose_username_screen.dart` | `views/auth/`, `views/user/` |
| `screens/kickoff_shell.dart`, `calendar_screen.dart`, `home_dashboard_screen.dart`, `placeholder_screen.dart` | `views/home/` |
| `screens/profile_screen.dart`, `edit_profile_screen.dart`, `people_screen.dart` | `views/user/` |
| `friends/friends_screen.dart`, `chat_screen.dart` | `views/friends/` |
| `screens/match/*` screens and `stadium_reviews_sheet.dart` | `views/match/` |
| `stadium/stadium_module.dart` (owner screens) | `views/stadium/` (split) |
| `challenges/screens/*` | `views/challenge/` |
| `tournaments/screens/*` | `views/tournament/` |
| `settings/settings_screen.dart` | `views/settings/` |
| `maps/map_picker_screen.dart` (screen part) | `views/maps/` (split) |

### items/
| From | To |
|---|---|
| `screens/match/match_widgets.dart`, `weather/match_weather_row.dart` | `items/match/` |
| `challenges/widgets/*` | `items/challenge/` |
| `daylight/daylight_service.dart` (`DaylightRow`), `travel/travel_service.dart` (`TravelRow`) | `items/challenge/` (split) |
| `tournaments/widgets/*`, `tournaments/tournament_constants.dart` | `items/tournament/` |
| `users/avatar_*`, `country_picker.dart`, `photo_source.dart`, `user_avatar.dart` | `items/user/` |
| `screens/kickoff_style.dart` | `items/kickoff_style.dart` |
| `achievement_icons.dart` | `items/awards/` |

`test/` mirrors the new layout (`test/services/...`, `test/views/...`).

## 4. Behavior alignment (small, on top of the move)

1. **Edit profile** becomes a real form: `Form` + `GlobalKey<FormState>` +
   `TextFormField` + `validator`.
2. **Routes:** a `routes:` map in `main.dart` and `pushNamed` for sign in,
   home, challenges, tournaments, stadiums, match and profile. Detail screens
   keep `push` with constructor arguments.
3. **HTTP constants:** `services/http_constants.dart` holds the base URLs
   (Nominatim, OSRM, weather, daylight, countries); services use it.
4. **Timeout** on `api_client`.
5. **FutureBuilder** on the main list screens where it replaces a manual
   loading flag without changing behavior.

## 5. Method

- Work in a separate folder: a `git worktree` on the branch
  `refactor/architecture` (created from `feat/firebase-only`), so the
  working app is never broken.
- Phase 1, moves: a script does `git mv` and rewrites every `import`,
  `export` and `part` in `lib/` and `test/`. No code changes.
- Phase 2, splits: the 5 mixed files are cut into entities, services, views
  and items. Same classes, new files.
- Phase 3, behavior alignment (section 4).
- Phase 4: move the tests, update `readme.md`, `AGENTS.md`, `CLAUDE.md`,
  `docs/tournaments.md` and the copilot file.
- After each phase: `flutter analyze` and `flutter test` (run by the
  developer), fix, then commit. One commit per phase, authored by the
  developer only.
- No logic changes and no class renames, so the existing tests keep meaning.

## 6. Done when

- `flutter analyze` is clean and `flutter test` passes (apart from the known
  red test in `test/tournaments_test.dart`).
- No file under `views/`, `items/` or `entities/` imports `package:http` or
  `cloud_firestore`, and no file outside `bd/` imports `sqflite`.
- `grep -r "package:http" lib` lists only files under `services/`.
- The app starts and the main flows (sign in, create a match, book a stadium,
  join a tournament, chat) work on a phone.
- Docs describe the new layout.

## 7. Risks

- About 113 `lib` files and 60 test files change paths; a missed import fails
  `flutter analyze`, which is why each phase ends with analyze.
- The 5 splits touch big files (`stadium_module.dart` is the largest).
- Merge conflicts with teammates working on `main`: merge the branch quickly
  after it is green, or tell the team to pause on `lib/`.
