import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../kickoff_style.dart';
import 'match_mock_data.dart';

const _pitch = Color(0xFF0B4FC4);
const _pitchBorder = Color(0x59FFFFFF);
const _pitchMarkings = Color(0x40FFFFFF);
const _slotEmptyBorder = Color(0x8CFFFFFF);
const _pitchSlots10 = [
  Offset(0.5, 0.1),
  Offset(0.2, 0.22),
  Offset(0.8, 0.22),
  Offset(0.35, 0.36),
  Offset(0.65, 0.36),
  Offset(0.35, 0.64),
  Offset(0.65, 0.64),
  Offset(0.2, 0.78),
  Offset(0.8, 0.78),
  Offset(0.5, 0.9),
];
const _pitchSlots8 = [
  Offset(0.5, 0.1),
  Offset(0.25, 0.26),
  Offset(0.75, 0.26),
  Offset(0.25, 0.48),
  Offset(0.75, 0.48),
  Offset(0.25, 0.7),
  Offset(0.75, 0.7),
  Offset(0.5, 0.9),
];

class MatchLobbyScreen extends StatelessWidget {
  const MatchLobbyScreen({required this.match, super.key});

  final MatchHomeMatch match;

  @override
  Widget build(BuildContext context) {
    final slots = match.capacity == 8 ? _pitchSlots8 : _pitchSlots10;
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Semantics(
                      label: 'Back to Match Home',
                      button: true,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: ExcludeSemantics(
                        child: IconButton(
                          tooltip: 'Back to Match Home',
                          onPressed: () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: KickoffColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  StatChip(
                    icon: match.isPublic
                        ? Icons.public_rounded
                        : Icons.lock_rounded,
                    label: '${match.players}/${match.capacity}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CodeCard(code: match.code),
              const SizedBox(height: 12),
              Expanded(
                child: PitchView(
                  capacity: match.capacity,
                  playerSlots: match.playerSlots,
                  coordinates: slots,
                  onTapSlot: (index) => _tapSlot(context, index),
                ),
              ),
              const SizedBox(height: 12),
              ChunkyButton(
                label: match.players >= match.capacity
                    ? 'Match full'
                    : 'Invite',
                icon: Icons.share_rounded,
                onPressed: match.players >= match.capacity
                    ? null
                    : () => _showShareSoon(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _tapSlot(BuildContext context, int index) {
    final initial = index < match.playerSlots.length
        ? match.playerSlots[index]
        : null;
    if (initial == null) {
      _showShareSoon(context);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KickoffColors.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            index == 0 ? 'You' : initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showShareSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Share coming soon')));
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: KickoffColors.panel,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              code,
              style: const TextStyle(
                color: KickoffColors.yellow,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: 5,
              ),
            ),
          ),
        ),
        Semantics(
          label: 'Copy match code',
          button: true,
          onTap: () => _copyCode(context),
          child: ExcludeSemantics(
            child: IconButton(
              tooltip: 'Copy match code',
              onPressed: () => _copyCode(context),
              icon: const Icon(Icons.content_copy_rounded, color: Colors.white),
            ),
          ),
        ),
        Semantics(
          label: 'Share match code',
          button: true,
          onTap: () => _showShareSoon(context),
          child: ExcludeSemantics(
            child: IconButton(
              tooltip: 'Share match code',
              onPressed: () => _showShareSoon(context),
              icon: const Icon(Icons.share_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    await HapticFeedback.lightImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  void _showShareSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Share coming soon')));
  }
}

class PitchView extends StatelessWidget {
  const PitchView({
    required this.capacity,
    required this.playerSlots,
    required this.coordinates,
    required this.onTapSlot,
    super.key,
  });

  final int capacity;
  final List<String?> playerSlots;
  final List<Offset> coordinates;
  final ValueChanged<int> onTapSlot;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      decoration: BoxDecoration(
        color: _pitch,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _pitchBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            const Positioned.fill(child: _PitchMarkings()),
            for (var index = 0; index < capacity; index++)
              if (index < coordinates.length)
                Positioned(
                  left: constraints.maxWidth * coordinates[index].dx - 24,
                  top: constraints.maxHeight * coordinates[index].dy - 24,
                  child: _AnimatedPlayerSlot(
                    index: index,
                    initial: index < playerSlots.length
                        ? playerSlots[index]
                        : null,
                    onTap: () => onTapSlot(index),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

class _PitchMarkings extends StatelessWidget {
  const _PitchMarkings();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PitchPainter(), child: const SizedBox.expand());
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pitchMarkings
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
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

class _AnimatedPlayerSlot extends StatefulWidget {
  const _AnimatedPlayerSlot({
    required this.index,
    required this.initial,
    required this.onTap,
  });

  final int index;
  final String? initial;
  final VoidCallback onTap;

  @override
  State<_AnimatedPlayerSlot> createState() => _AnimatedPlayerSlotState();
}

class _AnimatedPlayerSlotState extends State<_AnimatedPlayerSlot> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.index * 28), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _visible ? 1 : 0.7,
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutBack,
    child: SizedBox(
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        label: widget.initial == null
            ? 'Player slot ${widget.index + 1}, empty'
            : widget.index == 0
            ? 'Player slot ${widget.index + 1}, You'
            : 'Player slot ${widget.index + 1}, ${widget.initial}',
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.initial == null
                          ? Colors.transparent
                          : KickoffColors.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: widget.initial == null
                        ? CustomPaint(
                            painter: _DashedSlotPainter(),
                            child: const Center(
                              child: Icon(
                                Icons.add_rounded,
                                color: _slotEmptyBorder,
                                size: 18,
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              widget.initial!,
                              style: const TextStyle(
                                color: KickoffColors.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedSlotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _slotEmptyBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dashCount = 16;
    final rect = Offset.zero & size;
    for (var index = 0; index < dashCount; index++) {
      final start = index * 2 * 3.141592653589793 / dashCount;
      final sweep = 3.141592653589793 / dashCount;
      canvas.drawArc(rect.deflate(1), start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedSlotPainter oldDelegate) => false;
}
