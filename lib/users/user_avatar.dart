import 'dart:io';

import 'package:flutter/material.dart';

import '../screens/kickoff_style.dart';
import 'avatar_palette.dart';

/// DiceBear avatar for a username: a free web service, no key. [size] is in
/// logical pixels; the image is asked for at twice that, or at [pixels] when
/// given (smaller pictures load faster).
Uri diceBearUrl(String seed, Color background, double size, {int? pixels}) {
  final hex = (background.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0');
  return Uri.https('api.dicebear.com', '/9.x/adventurer/png', {
    'seed': seed,
    'size': '${(pixels ?? (size * 2).round()).clamp(32, 512)}',
    'backgroundColor': hex,
  });
}

/// What goes inside the round avatar: the player's photo when they chose one,
/// otherwise a DiceBear avatar over the colour they picked. The plain colour
/// shows while the image loads and when the phone is offline.
class UserAvatarFace extends StatelessWidget {
  const UserAvatarFace({
    required this.username,
    required this.avatarId,
    required this.size,
    this.photoPath,
    this.previewPixels,
    super.key,
  });

  /// Asks DiceBear for a smaller picture, for grids that show many avatars.
  final int? previewPixels;

  final String username;
  final int avatarId;
  final double size;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final color = avatarColor(avatarId);
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
              pixels: previewPixels,
            ).toString(),
            key: const ValueKey('avatar_dicebear'),
            fit: BoxFit.cover,
            width: size,
            height: size,
            gaplessPlayback: true,
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
          children: [image],
        ),
      ),
    );
  }
}
