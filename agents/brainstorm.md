# 🧠 Brainstorm — Tournaments Module

## Project: Football Match App
## Module: Tournaments
## Date: October 2026

---

## What is the Tournaments Module?

A module that allows football app users to:
- Discover and browse tournaments
- View tournament details, participants, and schedules
- Join tournaments
- Track standings, brackets, and results

---

## 🎯 Core Questions to Answer

### Who uses this module?
| User Type | What they want |
|---|---|
| Player | Find and join tournaments near me |
| Team Captain | Register the team in a tournament |
| Fan | Follow tournament progress and results |
| Admin | Create and manage tournaments |

### What problems does it solve?
- Players don't know what tournaments are available
- Hard to track standings without a central place
- Joining tournaments is usually done manually (WhatsApp, paper)

---

## 🏆 Features Brainstorm

### Must Have (MVP)
- [ ] List of tournaments (name, date, status, spots left)
- [ ] Tournament detail page (info, teams, format)
- [ ] Join a tournament
- [ ] View standings / bracket

### Should Have
- [ ] Filter tournaments (by status, format, location)
- [ ] Search tournaments by name
- [ ] Tournament history (past results)
- [ ] Notification when tournament starts

### Nice to Have (Future)
- [ ] Bracket visualization (knockout tree)
- [ ] Live score updates during tournament matches
- [ ] Share tournament link
- [ ] Tournament chat/comments
- [ ] Create tournament (admin role)

---

## 🗂️ Tournament Types to Support

| Format | How it works |
|---|---|
| **Knockout** | Lose once = eliminated, winner advances |
| **League** | Everyone plays everyone, points-based |
| **Group Stage + Knockout** | Groups first, then elimination |
| **Round Robin** | Each team plays each other once |

---

## 📊 Data We Need

### Tournament Object
```
id, name, description, format, status,
start_date, end_date, max_teams, current_teams,
prize, location, created_by
```

### Standing/Table Row
```
position, team_id, team_name, played,
wins, draws, losses, goals_for,
goals_against, goal_difference, points
```

### Bracket Match
```
match_id, round, team_home, team_away,
score_home, score_away, date, status
```

---

## 🔌 API Brainstorm

### Endpoints needed from backend team:
```
GET  /tournaments                    List all tournaments
GET  /tournaments?status=active      Filter by status
GET  /tournaments/:id                Tournament details
GET  /tournaments/:id/teams          Teams in tournament
GET  /tournaments/:id/standings      League standings
GET  /tournaments/:id/bracket        Knockout bracket
POST /tournaments/:id/join           Join tournament
POST /tournaments                    Create tournament (admin)
```

### Questions for backend team:
- Is authentication required to join?
- Can a user join as individual or as a team?
- What happens when tournament is full?
- How is the bracket generated (automatic or manual)?

---

## 🎨 UI Brainstorm

### What should the list card show?
- Tournament name + sport icon
- Date range
- Format (Knockout / League)
- Status badge (Active / Upcoming / Finished)
- Spots remaining (e.g., "4/16 teams")
- Quick action button (Join / View)

### What makes a great detail page?
- Hero section with tournament name and status
- Tabs: About / Teams / Standings / Schedule
- Clear CTA (Join button or "Tournament Full")
- Show progress if ongoing

### What makes standings readable?
- Ranked list with position numbers
- Medal icons for top 3 🥇🥈🥉
- Color highlight for user's own team
- Sortable columns

---

## ⚠️ Edge Cases to Handle

| Scenario | How to handle |
|---|---|
| Tournament is full | Disable join button, show "Full" badge |
| User already joined | Show "Joined ✓" instead of join button |
| No tournaments available | Show empty state illustration |
| Tournament cancelled | Show "Cancelled" badge, grey out card |
| Network error | Show retry button |
| User not logged in | Redirect to login before joining |

---

## 🧩 Reusable Widgets to Build

- `TournamentCard` — used in list screen
- `StatusBadge` — colored pill (Active/Upcoming/Finished)
- `StandingsTable` — ranked team table
- `BracketView` — knockout bracket visualization
- `TeamAvatarRow` — row of team icons/names

---

## 📅 Suggested Development Order

```
Week 1:
  ✅ Define Tournament model
  ✅ Build TournamentService (list + detail endpoints)
  ✅ Build Tournaments List Screen
  ✅ Build Tournament Card widget

Week 2:
  ✅ Tournament Detail Screen (tabs)
  ✅ Standings Screen
  ✅ Join Tournament flow
  ✅ Error & loading states

Week 3 (if time allows):
  ✅ Search & filter
  ✅ Bracket view
  ✅ Polish UI
```

---

## 💬 Open Questions for the Team

1. Do we need admin functionality (create tournament) in this sprint?
2. Is joining as a team or as an individual player?
3. Does the backend already have tournament endpoints ready?
4. What's the tournament data structure from the backend?
5. Should standings update in real time or only on refresh?
