import 'package:flutter/material.dart';

/// Colours a player can pick for their avatar. The number saved in the
/// profile is the position in this list.
const avatarColors = <Color>[
  Color(0xFFFFD21F), // yellow, the default
  Color(0xFFFFA24A), // orange
  Color(0xFF7DE3B0), // mint
  Color(0xFF8CC8FF), // sky
  Color(0xFFFF9EC4), // pink
  Color(0xFFC3A6FF), // lilac
];

Color avatarColor(int id) => avatarColors[id.abs() % avatarColors.length];
