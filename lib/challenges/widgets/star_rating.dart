import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    required this.rating,
    this.onChanged,
    this.size = 20,
    super.key,
  });

  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final iconSize = size * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= rating;

        final icon = Icon(
          isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isFilled ? KickoffColors.yellow : KickoffColors.dim,
          size: iconSize,
        );

        if (onChanged == null) return icon;

        return IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: iconSize + 6 * scale,
            minHeight: iconSize + 6 * scale,
          ),
          icon: icon,
          onPressed: () => onChanged!(starIndex),
        );
      }),
    );
  }
}
