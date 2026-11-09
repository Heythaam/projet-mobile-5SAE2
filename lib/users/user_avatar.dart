import 'dart:io';

import 'package:flutter/material.dart';

import '../screens/kickoff_style.dart';
import 'avatar_palette.dart';

/// DiceBear avatar for a username: a free web service, no key. [size] is in
/// logical pixels; the image is asked for at twice that.
Uri diceBearUrl(String seed, Color background, double size) {
  final hex = (background.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0');
  return Uri.https('api.dicebear.com', '/9.x/adventurer/png', {
    'seed': seed,
    'size': '${(size * 2).round().clamp(32, 512)}',
    'backgroundColor': hex,
  });
}

/// What goes inside the round avatar: the player's photo when they chose one,
/// otherwise a DiceBear avatar over the colour they picked. The coloured initial
/// shows while the image loads and when the phone is offline.
class UserAvatarFace extends StatelessWidget {
  const UserAvatarFace({
    required this.username,
    required this.avatarId,
    required this.size,
    this.photoPath,
    super.key,
  });

  final String username;
  final int avatarId;
  final double size;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final color = avatarColor(avatarId);
    final initial = Text(
      username.isEmpty ? '?' : username[0].toUpperCase(),
      style: TextStyle(
        color: KickoffColors.ink,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w500,
      ),
    );
    final path = photoPath;
    final Widget image = path != null
        ? Image.file(
            File(path),
            key: const ValueKey('avatar_photo'),
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : Image.network(
            diceBearUrl(
              avatarLook(avatarId) == 0
                  ? username
                  : '$username-${avatarLook(avatarId)}',
              color,
              size,
            ).toString(),
            key: const ValueKey('avatar_dicebear'),
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: color,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [Center(child: initial), image],
        ),
      ),
    );
  }
}
