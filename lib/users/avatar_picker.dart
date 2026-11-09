import 'package:flutter/material.dart';

import '../screens/kickoff_style.dart';
import 'avatar_palette.dart';
import 'user_avatar.dart';

/// How many characters the picker offers.
const avatarChoices = 40;

/// Pop-up with a grid of avatars. Returns the chosen look (see [avatarLook]) or
/// null when the player closes it. [colour] is the colour already picked.
Future<int?> pickAvatarLook(
  BuildContext context, {
  required String username,
  required int colour,
  required int currentLook,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  backgroundColor: KickoffColors.panelDark,
  builder: (_) => _AvatarSheet(
    username: username,
    colour: colour,
    currentLook: currentLook,
  ),
);

class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet({
    required this.username,
    required this.colour,
    required this.currentLook,
  });

  final String username;
  final int colour;
  final int currentLook;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Choose your avatar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              key: const ValueKey('avatar_grid'),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: avatarChoices,
              itemBuilder: (context, look) {
                final selected = look == currentLook;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Avatar ${look + 1}',
                  child: InkResponse(
                    key: ValueKey('avatar_choice_$look'),
                    onTap: () => Navigator.of(context).pop(look),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: UserAvatarFace(
                        username: username,
                        avatarId: look * avatarColors.length + colour,
                        size: 72,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
