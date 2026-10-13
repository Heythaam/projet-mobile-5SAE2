import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import 'match_mock_data.dart';

const _pitchColor = Color(0xFF0B4FC4);
const _pitchLineColor = Color(0x59FFFFFF);

class StepBar extends StatelessWidget {
  const StepBar({required this.current, super.key});

  final int current;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var step = 1; step <= 4; step++) ...[
        if (step > 1) const SizedBox(width: 6),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 8,
            decoration: BoxDecoration(
              color: step <= current
                  ? KickoffColors.yellow
                  : KickoffColors.panel,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ],
  );
}

class StadiumArt extends StatelessWidget {
  const StadiumArt({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _pitchColor,
    child: CustomPaint(
      painter: _PitchPainter(),
      child: const SizedBox.expand(),
    ),
  );
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pitchLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final inset = Rect.fromLTWH(
      14,
      14,
      (size.width - 28).clamp(0, size.width),
      (size.height - 28).clamp(0, size.height),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, const Radius.circular(8)),
      paint,
    );
    canvas.drawLine(
      Offset(inset.left, size.height / 2),
      Offset(inset.right, size.height / 2),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.1,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => false;
}

class PillToggle extends StatelessWidget {
  const PillToggle({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: KickoffColors.panel,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleSegment(
          icon: Icons.vpn_key_rounded,
          label: 'Join with code',
          selected: selectedIndex == 0,
          onTap: () => onChanged(0),
        ),
        _ToggleSegment(
          icon: Icons.public_rounded,
          label: 'Public matches',
          selected: selectedIndex == 1,
          onTap: () => onChanged(1),
        ),
      ],
    ),
  );
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 64,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? KickoffColors.yellow : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            icon,
            color: selected ? KickoffColors.ink : KickoffColors.muted,
            size: 26,
          ),
        ),
      ),
    ),
  );
}

class CodeBoxes extends StatelessWidget {
  const CodeBoxes({required this.code, required this.invalid, super.key});

  final String code;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final activeIndex = code.length.clamp(0, 4);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < 5; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: AspectRatio(
              aspectRatio: 52 / 66,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KickoffColors.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: invalid
                        ? KickoffColors.red
                        : index == activeIndex && code.length < 5
                        ? KickoffColors.yellow
                        : const Color(0xFF4A5AA8),
                    width: 3,
                  ),
                ),
                child: Text(
                  index < code.length ? code[index] : '_',
                  style: TextStyle(
                    color: index < code.length
                        ? Colors.white
                        : KickoffColors.dim,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class MatchRow extends StatelessWidget {
  const MatchRow({
    required this.match,
    required this.timeLabel,
    required this.onJoin,
    super.key,
  });

  final MatchHomeMatch match;
  final String timeLabel;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final full = match.players >= match.capacity;
    return Semantics(
      button: !full,
      enabled: !full,
      label: full
          ? '${match.stadium}, $timeLabel, match full'
          : 'Join ${match.stadium} $timeLabel',
      onTap: full ? null : onJoin,
      child: ExcludeSemantics(
        child: Material(
          color: KickoffColors.blue,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: full ? null : onJoin,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: const Border(
                  bottom: BorderSide(color: KickoffColors.blueDark, width: 5),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              color: KickoffColors.yellow,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                match.stadium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: SlotDots(
                            joined: match.players,
                            total: match.capacity,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: full
                              ? KickoffColors.panel
                              : KickoffColors.yellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          full ? Icons.lock_rounded : Icons.add_rounded,
                          color: full ? KickoffColors.dim : KickoffColors.ink,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
