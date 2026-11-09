# 🎨 UI/UX Designer — Tournaments Module

## Role
You are the UI/UX designer for the Tournaments module. You define how the screens look, feel, and flow. Your designs must be clean, intuitive, and consistent with the rest of the football app.

---

## Design Principles
1. **Clarity** — Users should know where they are and what to do at a glance
2. **Consistency** — Match the style of the existing app screens
3. **Feedback** — Every action gets a visual response (loading, success, error)
4. **Mobile First** — Design for small screens, thumb-friendly tap targets

---

## Color Palette (Football Theme)
| Role | Color | Usage |
|---|---|---|
| Primary | `#1B5E20` (dark green) | Buttons, active tabs, headers |
| Accent | `#FFD700` (gold) | Highlights, badges, rankings |
| Background | `#121212` (dark) | Screen backgrounds |
| Surface | `#1E1E1E` | Cards, containers |
| Text Primary | `#FFFFFF` | Titles, main content |
| Text Secondary | `#9E9E9E` | Subtitles, metadata |
| Success | `#4CAF50` | Win, joined, active |
| Error | `#F44336` | Loss, error messages |

---

## Typography
| Element | Size | Weight |
|---|---|---|
| Screen Title | 22sp | Bold |
| Card Title | 16sp | SemiBold |
| Body Text | 14sp | Regular |
| Caption/Meta | 12sp | Regular |

---

## Screens to Design

### 1. 📋 Tournaments List Screen
```
┌─────────────────────────────┐
│  🏆 Tournaments        [🔍] │  ← AppBar with search
├─────────────────────────────┤
│  [All]  [Active]  [Upcoming]│  ← Filter tabs
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 🏆 Champions Cup        │ │  ← Tournament Card
│ │ 📅 Oct 15 – Nov 10      │ │
│ │ 👥 8/16 teams  ● Active │ │
│ │           [View Details]│ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 🥇 City League          │ │
│ │ 📅 Nov 20 – Dec 5       │ │
│ │ 👥 4/8 teams ● Upcoming │ │
│ │              [Join Now] │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

### 2. 📄 Tournament Detail Screen
```
┌─────────────────────────────┐
│  ←  Champions Cup      [⋮] │  ← AppBar
├─────────────────────────────┤
│  🏆                         │
│  Champions Cup              │  ← Banner/Hero section
│  ● Active  |  Oct 15–Nov 10 │
├─────────────────────────────┤
│  [About] [Teams] [Standings]│  ← Tabs
├─────────────────────────────┤
│  Format: Knockout           │  ← About Tab
│  Teams: 8/16                │
│  Prize: Trophy + Medal      │
│                             │
│  ┌───────────────────────┐  │
│  │    [Join Tournament]  │  │  ← CTA Button
│  └───────────────────────┘  │
└─────────────────────────────┘
```

### 3. 🏅 Standings Screen
```
┌─────────────────────────────┐
│  ← Standings                │
├─────────────────────────────┤
│  #   Team        W   D   L  │  ← Table Header
│  ─────────────────────────  │
│  🥇 1. FC Stars  5   1   0  │
│  🥈 2. Red Lions 4   2   1  │
│  🥉 3. Blue FC   3   1   2  │
│     4. United    2   0   4  │
└─────────────────────────────┘
```

---

## Component Specs

### Tournament Card
- Border radius: `12px`
- Padding: `16px`
- Status badge: pill shape, colored by status
  - Active → green background
  - Upcoming → blue background
  - Finished → grey background
- Shadow: subtle `BoxShadow` elevation 2

### Buttons
- Primary (Join/View): full width, rounded `12px`, green
- Height: `48px` minimum (thumb friendly)
- Disabled state: greyed out, no interaction

### Status Indicators
```
● Active    → green dot
● Upcoming  → blue dot
● Finished  → grey dot
● Full      → red dot
```

---

## UX Rules
- **Empty state:** Show an illustration + message when no tournaments exist
- **Loading:** Show skeleton cards while fetching, not just a spinner
- **Pull to refresh:** Users can pull down to refresh the list
- **Error state:** Show a retry button, not just an error message
- **Join confirmation:** Show a bottom sheet confirmation before joining

---

## Navigation Flow
```
Home Screen
    ↓
Tournaments List  →  Tournament Detail  →  Standings
                           ↓
                      Join Confirmation
                           ↓
                      Success Message
```
