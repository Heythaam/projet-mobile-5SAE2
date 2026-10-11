import 'package:flutter/material.dart';

/// Icon for an achievement's `icon` name from the API.
IconData achievementIcon(String name) => switch (name) {
  'whistle' => Icons.sports_rounded,
  'team' => Icons.groups_2_rounded,
  'formation' => Icons.grid_view_rounded,
  'chat' => Icons.forum_rounded,
  'star' => Icons.stars_rounded,
  'flame' => Icons.local_fire_department_rounded,
  'crown' => Icons.workspace_premium_rounded,
  _ => Icons.military_tech_rounded,
};
