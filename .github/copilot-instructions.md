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
# MASTER CONTEXT — Kickoff "Match" module (Flutter)

## 1. Goal
Build the whole **Match module** of my football (soccer) social app "Kickoff" in Flutter.
Today the module is only a placeholder screen: dark navy background (#1A1A4E), a back arrow at the top-left, a yellow football icon, the word "Match" and the text "Coming soon".
Find that placeholder (search the project for "Coming soon") and replace it. **This screen becomes the Match Home screen and the entry point of the whole module.**
The result must be a pixel-faithful, polished Flutter implementation of the six mockups in the HTML file `docs/design/kickoff_match_flow_prototypes.html` (the source of truth for the design).

## 2. Tech constraints
- Flutter + Dart (null-safe). Before writing code, read `pubspec.yaml` and the existing `lib/` structure and **follow the conventions already in the project** (folder layout, naming, routing approach, state management, theme, font).
- State management: use whatever the project already uses. If there is none, use Riverpod.
- Routing: use the project's existing navigation approach (Navigator 1 / go_router / etc.). Do not introduce a second router.
- Local data: **SQLite via `sqflite`** (+ `path`). No network, no backend yet. Put all DB access behind a repository interface so a remote API can replace it later without touching the UI.
- Allowed new packages (add only if not present): `sqflite`, `path`, `share_plus`, `intl`, and one Tabler icon package for Flutter (e.g. `flutter_tabler_icons`). Verify each icon name exists in the package; if one is missing, use the closest Material icon and leave a `// TODO(icon)` comment. Do not add other packages without asking.
- Do not modify other modules. Only touch shared files (theme, router, main) when strictly needed and say exactly what you changed.

## 3. How to read the HTML prototype
- Each phone is a `<div class="ph">` (a 420px-tall mock screen). The caption below each phone gives the screen name.
- Almost all layout and colour values are in **inline `style` attributes** and in the small `<style>` block with classes `.ph .tb .av .chip .nav .cta .steps .back .d .s .box .row`. Read both.
- Icons are Tabler icons (`<i class="ti ti-...">`). Use the same icon names.
- The mock is drawn at roughly 240px wide, but real phones are about 360–412dp wide. **Do not copy pixel values literally.** Use the dp values in section 5 (already scaled), and build layouts with Column/Row/Expanded/Flexible/Stack-with-Align, never hard-coded absolute offsets from the HTML. The result must look right from 320dp to 430dp wide and on tall (20:9) screens.
- The mocks use `position:absolute` only because they are static drawings. In Flutter, use proper responsive layout.

## 4. Design tokens (create `lib/features/match/presentation/theme/kickoff_tokens.dart`)
```dart
class K {
  // Surfaces
  static const navy        = Color(0xFF1A1A4E); // screen background
  static const navyDeep    = Color(0xFF0A0A2E); // avatar ring
  static const surface     = Color(0xFF2D3A7A); // cards, chips, nav, keypad
  static const surfaceLine = Color(0xFF4A5AA8); // empty code-box border

  // Brand
  static const yellow      = Color(0xFFFFD21F); // primary CTA, accents
  static const yellowEdge  = Color(0xFFC9A000); // 3D bottom edge of yellow buttons
  static const blue        = Color(0xFF0B5FE8); // secondary buttons / rows
  static const blueEdge    = Color(0xFF0A3F9C); // 3D bottom edge of blue buttons
  static const pitch       = Color(0xFF0B4FC4); // pitch / stadium art background

  // Text & icons
  static const onNavy      = Colors.white;
  static const muted       = Color(0xFFB9C3EE); // secondary text, inactive nav icons
  static const mutedDim    = Color(0xFF8D99D6); // empty dots, placeholders, chevrons
  static const onYellow    = Color(0xFF1A1A4E); // text/icons on yellow
  static const flame       = Color(0xFFFFA24A); // streak
  static const pitchLine   = Color(0x59FFFFFF); // white @ ~35%
  static const pitchLineSoft = Color(0x40FFFFFF); // white @ ~25%
  static const slotEmpty   = Color(0x8CFFFFFF); // dashed border white @ ~55%
  static const danger      = Color(0xFFFF5A5F); // errors (not in prototype; used for invalid code)
}
```
Typography: use the app's existing font. **Do NOT use a monospace font** (the placeholder currently shows one by accident). Weights: 500–600 for all labels/values, 400 for small captions.
Spacing grid: 4 / 8 / 12 / 16 / 24.

## 5. Dimensions (Flutter dp, already scaled from the mock; tune ±10% by eye against the HTML at 360dp wide)
| Element | Spec |
|---|---|
| Screen horizontal padding | 16 |
| Avatar | 40 circle, yellow fill, initial in navy w600 16, 2px `navyDeep` ring |
| Stat chip (Lv / streak / energy / meta chips) | height 28, h-padding 12, radius 14, fill `surface`, text 14 w600, icon 16, gap 4 |
| Big action card (Create / Join) | height 150, radius 22, bottom edge 6 (3D), icon 44, label 18 w600 |
| Next-match card | fill `surface`, radius 20, padding 16; date row 13–14 `muted`; stadium 20 w600; capacity dots 12 dia, gap 5 |
| Primary CTA button | height 56, radius 28 (pill), bottom edge 5 (3D), label 18 w600, icon 22; pinned to bottom with 16 margin + SafeArea |
| Step progress bar | 4 segments, height 8, radius 4, gap 6; on = `yellow`, off = `surface`; sits right of the back arrow |
| Back arrow | icon 28, `muted`, top-left, 48dp tap target |
| Stadium card | radius 22, border 4 `yellow`, fill `blue`; art area ≈ 52% of card height; body padding 16; name 20 w600 |
| Visibility card (Public / Private) | height 170, radius 22, icon 52, label 18 w600; unselected = blue + bottom edge 6; selected = 4px yellow border all round, lock/world icon turns yellow |
| Lobby code card | height 76, radius 20, `surface`; code 34 w700 letterSpacing 5 `yellow`; copy + share icons 28 |
| Pitch | radius 18, fill `pitch`, 2px `pitchLine` border, halfway line, centre circle ≈ 20% of pitch width |
| Player slot | 38 circle; filled = yellow + initial (navy w700 16); empty = 2px dashed `slotEmpty` + plus icon 18 |
| Code box | 52 × 66, radius 14, fill `surface`, border 3 `surfaceLine`, char 28 w700; active box border `yellow`; empty char "_" in `mutedDim` |
| Keypad key | chip style (fill `surface`, radius 14), vertical padding 14, text 18 w600 |
| Segmented toggle (key / world) | fill `surface`, radius 26, inner padding 4; segment padding 8×28, icon 26; selected = `yellow` pill with `onYellow` icon; unselected icon `muted` |
| Public match row | fill `blue`, radius 20, padding 14, bottom edge 5 `blueEdge`; time 24 w600 (min width 64); stadium 16 w600 with yellow map-pin; dots 11 dia; trailing button radius 16, padding 12×14, icon 24 |
| Bottom nav | 64 + safe area, fill `surface`, 4 icons size 28, active = `yellow`, inactive = `muted` |

## 6. Shared widgets (build once, reuse everywhere) — `lib/features/match/presentation/widgets/`
- `ChunkyButton` — the 3D "Duolingo-style" button. Parameters: `variant` (yellow | blue | surface), `child`, `onPressed`, `height`, `radius`, `edge`. Visual: solid colour + a darker bottom edge (`edge` px). **On press:** the button translates down by `edge` px and the edge shrinks to 0 (animate ~80–100 ms, `Curves.easeOut`), light haptic. Disabled state: 40% opacity and no press animation. Must be used for the CTA, Create/Join cards, visibility cards (unselected) and public match rows.
- `StatChip` — rounded chip with optional leading icon and optional colours (e.g. flame = orange text, energy = yellow text).
- `DotsRow(capacity, filled)` — row of dots: filled = solid yellow, empty = transparent with 1.5px `mutedDim` border. Wrap if capacity is large.
- `StepBar(total: 4, current: n)`.
- `PillToggle` — two-segment icon toggle (key / world).
- `PitchView(capacity, slots, onSlotTap)` + `PlayerSlot` — pitch with lines and slots positioned by percentage coordinates (see Prompt 3).
- `StadiumArt` — the simple pitch drawing inside the stadium card, built with `CustomPainter` (inset rounded rectangle, halfway line, centre circle, all `pitchLine`).
- `CodeBoxes(length: 5, value)` and `CodeKeypad(onKey, onBackspace)`.
- `MatchRow(match)`.
- `KickoffBottomNav` — **reuse the app's existing bottom navigation if one exists** (the mock shows 4 tabs: ball-football (active, yellow), mail, trophy, user). Only create it if the app has none, and then just as a visual component.
Every tappable widget needs `Semantics` labels and a minimum 48×48dp hit area.

## 7. Data model (SQLite, via `sqflite`)
Create `lib/features/match/data/match_database.dart` with versioned migrations (`onCreate`, `onUpgrade`) and these tables:
```sql
CREATE TABLE stadiums(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  distance_km REAL NOT NULL,
  price_coins INTEGER NOT NULL,
  capacity INTEGER NOT NULL,
  art_variant INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE matches(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stadium_id INTEGER NOT NULL REFERENCES stadiums(id),
  starts_at INTEGER NOT NULL,            -- epoch millis, local time
  visibility TEXT NOT NULL CHECK (visibility IN ('public','private')),
  code TEXT NOT NULL UNIQUE,             -- 5 chars
  capacity INTEGER NOT NULL,
  creator_id TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE match_players(
  match_id INTEGER NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  slot_index INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (match_id, slot_index),
  UNIQUE (match_id, user_id)
);
```
- Enable `PRAGMA foreign_keys = ON` in `onConfigure`.
- The current user: reuse the app's existing user/profile source if there is one (name, level, streak, energy). If not, create a tiny `profile` table or a hard-coded `CurrentUser` stub (id `me`, name "U", level 1, streak 1, energy 50) behind an interface.
- Match code: 5 characters from the alphabet `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no 0/O/1/I/L to avoid confusion). Generate with `Random.secure()`, retry on UNIQUE collision. Codes are always stored/compared in upper case.
- **Seed data** (only when the DB is created, debug-friendly):
  - Stadiums: Green Arena (2.0 km, 40 coins, capacity 10), City Pitch (3.5 km, 30 coins, capacity 8), Sport Hall (5.2 km, 25 coins, capacity 8), Riverside Park (7.8 km, 20 coins, capacity 10).
  - Fake players with display names A, S, M, Y, K, R (user ids `p_a`, `p_s`, …).
  - A **private** match at Green Arena, next Saturday 18:00, code `K7X92`, capacity 10, creator = current user, with 7 players: U (me), A, S, M, Y, K, R in the slot order shown in the lobby mock. This is the match shown on Home.
  - **Public** matches: Green Arena today 18:00 (cap 10, 6 players), City Pitch today 20:00 (cap 8, 2 players), Sport Hall next Sunday (cap 8, 8 players = full).
- Repository interface `MatchRepository`:
  - `Future<MatchSummary?> getMyUpcomingMatch()`
  - `Future<List<Stadium>> getStadiums()`
  - `Future<Match> createMatch({stadiumId, startsAt, visibility})` → creator is placed in slot 0
  - `Future<List<MatchSummary>> getPublicMatches()` (upcoming only, ordered by `starts_at`)
  - `Future<Match> getMatch(int id)` (with players)
  - `Future<Match> joinByCode(String code)` / `Future<Match> joinPublic(int matchId)` — both throw typed exceptions: `MatchNotFound`, `MatchFull`, `AlreadyJoined`, `MatchInPast`
  - `Future<Match> joinSlot(int matchId, int slotIndex)` (optional) 
  Implement it as `SqliteMatchRepository`. Immutable models (`Stadium`, `Match`, `MatchPlayer`, `MatchSummary`) with `fromMap`/`toMap`.
- Dates: use `intl`. Formats: "Sat 18:00" (date line on Home), "18:00" (today in list), "Sun" (other days in list).

## 8. Folder structure (adapt to project conventions)
```
lib/features/match/
  data/        match_database.dart, sqlite_match_repository.dart, seed.dart
  domain/      models/, match_repository.dart, exceptions.dart
  application/ providers or controllers (match_home, create_match, lobby, join)
  presentation/
    theme/     kickoff_tokens.dart
    widgets/   (section 6)
    screens/   match_home_screen.dart, stadium_pick_screen.dart, datetime_pick_screen.dart,
               visibility_screen.dart, lobby_screen.dart, join_screen.dart
```

## 9. Navigation flow
```
Match Home ──Create──▶ 1 Stadium ▶ 2 Date & time ▶ 3 Public/Private ──Create──▶ Lobby (replaces the create stack)
          ──Join────▶ Join screen (tab: code) ⇄ (tab: public matches)  ──join success──▶ Lobby
          ──tap next-match card──▶ Lobby
```
- The existing back arrow behaviour stays. In the create flow, back goes to the previous step; from step 1 it returns to Match Home.
- After creating or joining, navigate to the Lobby with **replace/pop-until-home** semantics so that Back from the Lobby returns to Match Home, never into the middle of the create flow.
- Match Home is the module root; it keeps the existing back arrow at top-left that already exists on the placeholder.

## 10. Quality rules
- No colour literals outside `kickoff_tokens.dart`. No magic numbers repeated: put sizes in a `KDims` class.
- All screens: `SafeArea`, no overflow on 320dp width, no overflow with large system font scale (clamp text scale to 1.2 on fixed-size components like code boxes).
- Handle loading, empty and error states (simple, in the same visual style: skeleton or centred muted text).
- Async DB calls never block the UI thread; no DB calls inside `build`.
- Dispose controllers/animations. Use `const` where possible.
- `flutter analyze` must be clean; add unit tests for the repository (use `sqflite_common_ffi` with an in-memory DB): code generation uniqueness/alphabet, create → creator in slot 0, join by code (not found / full / already joined), join public, public list ordering.
- Keep each screen file focused; extract widgets instead of 500-line `build` methods.
- Small, readable commits per prompt. After finishing each prompt: list the files created/changed and anything you assumed.
- If something in the HTML is ambiguous, pick the most natural option, implement it, and list it under "Assumptions" at the end of your answer. Don't stop to ask unless it blocks compilation.