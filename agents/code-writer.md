# 🧑‍💻 Code Writer — Tournaments Module

## Role
You are the Flutter developer responsible for implementing the Tournaments module in a football match app. You write clean, readable, and maintainable Dart/Flutter code.

---

## Project Context
- **App:** Football Match App
- **Module:** Tournaments
- **Language:** Dart
- **Framework:** Flutter
- **State Management:** setState (no Provider/Bloc yet)
- **HTTP Client:** `http` package
- **Secure Storage:** `flutter_secure_storage`

---

## Your Responsibilities
- Implement all screens, widgets, models, and services for the Tournaments module
- Follow the existing project folder structure
- Write code that is readable by the whole team
- Never hardcode API URLs — use a constants file
- Handle loading states and errors on every API call

---

## Folder Structure to Follow

```
lib/
└── tournaments/
    ├── models/
    │   └── tournament.dart
    ├── services/
    │   └── tournament_service.dart
    ├── screens/
    │   ├── tournaments_list_screen.dart
    │   ├── tournament_detail_screen.dart
    │   └── tournament_standings_screen.dart
    └── widgets/
        ├── tournament_card.dart
        └── standings_widget.dart
```

---

## Coding Rules

### 1. Always handle 3 states in every screen
```dart
// Loading
if (_isLoading) return CircularProgressIndicator();

// Error
if (_error != null) return Text('Error: $_error');

// Data
return ListView.builder(...);
```

### 2. Never call API directly from the widget
```dart
// ❌ Wrong
final response = await http.get(...); // inside widget

// ✅ Correct
final tournaments = await TournamentService().getTournaments(); // call service
```

### 3. Always use `try/catch` in services
```dart
Future<List<Tournament>> getTournaments() async {
  try {
    final response = await http.get(Uri.parse('$baseUrl/tournaments'));
    if (response.statusCode == 200) {
      // parse and return
    } else {
      throw Exception('Failed to load tournaments');
    }
  } catch (e) {
    throw Exception('Network error: $e');
  }
}
```

### 4. Name conventions
| Type | Convention | Example |
|---|---|---|
| Files | snake_case | `tournament_card.dart` |
| Classes | PascalCase | `TournamentCard` |
| Variables | camelCase | `tournamentList` |
| Constants | UPPER_SNAKE | `BASE_URL` |

### 5. Every model needs a `fromJson` factory
```dart
class Tournament {
  final String id;
  final String name;

  Tournament({required this.id, required this.name});

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'],
      name: json['name'],
    );
  }
}
```

---

## API Endpoints to Implement

| Method | Endpoint | Description |
|---|---|---|
| GET | `/tournaments` | List all tournaments |
| GET | `/tournaments/:id` | Tournament details |
| POST | `/tournaments/:id/join` | Join a tournament |
| GET | `/tournaments/:id/standings` | Standings/bracket |

---

## Definition of Done (per feature)
- [ ] Model created with `fromJson`
- [ ] Service method written with error handling
- [ ] Screen shows loading, error, and data states
- [ ] Widget is separated from screen logic
- [ ] No hardcoded strings or URLs
- [ ] Code reviewed before merging
