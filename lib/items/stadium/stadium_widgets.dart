// Small widgets and helpers shared by the stadium screens.

import 'package:flutter/material.dart';

import '../../services/stadium/stadium_api.dart';
import '../kickoff_style.dart';

const stadiumSlotChoices = [60, 90, 120];

const stadiumDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

const stadiumDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const stadiumDayFullNames = [
  'Mondays',
  'Tuesdays',
  'Wednesdays',
  'Thursdays',
  'Fridays',
  'Saturdays',
  'Sundays',
];

const stadiumMaxPitches = 8;

abstract final class StadiumColors {
  static const green = Color(0xFF1FA25B);
  static const greenDark = Color(0xFF15703F);
  static const pending = KickoffColors.orange;
  static const pendingDark = Color(0xFFC46F1F);
}

String stadiumSlotLabel(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${minutes / 60}h';

String stadiumShortDate(DateTime date) =>
    '${stadiumDayNames[date.weekday - 1]} ${date.day}';

DateTime stadiumDateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String stadiumMessage(Object error) =>
    error is StadiumApiException ? error.message : 'Something went wrong.';

void stadiumToast(BuildContext context, String message, {bool error = false}) {
  final scale = kickoffScale(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // Float above the chunky bottom button instead of covering it.
        margin: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 84 * scale),
        backgroundColor: error
            ? KickoffColors.redDark
            : KickoffColors.panelDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        content: Text(message, style: stadiumText(scale, 15)),
      ),
    );
}

class StadiumPage extends StatelessWidget {
  const StadiumPage({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actions = const [],
    this.bottom,
    this.header,
    this.onBack,
  });

  final String title;
  final IconData? icon;
  final List<Widget> actions;
  final Widget child;
  final Widget? bottom;
  final Widget? header;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                4 * scale,
                4 * scale,
                8 * scale,
                4 * scale,
              ),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  if (icon != null) ...[
                    Icon(icon, color: KickoffColors.yellow, size: 26 * scale),
                    SizedBox(width: 8 * scale),
                  ] else
                    SizedBox(width: 4 * scale),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: stadiumText(scale, 21, weight: FontWeight.w600),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            ?header,
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  8 * scale,
                  16 * scale,
                  12 * scale,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class StadiumChunkyTile extends StatelessWidget {
  const StadiumChunkyTile({
    super.key,
    required this.color,
    required this.edge,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.radius = 18,
    this.edgeWidth = 4,
    this.semanticLabel,
  });

  final Color color;
  final Color edge;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final double edgeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final shape = BorderRadius.circular(radius * scale);
    final tile = Material(
      color: color,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 48 * scale),
          padding: padding,
          decoration: BoxDecoration(
            border: edgeWidth == 0
                ? null
                : Border(
                    bottom: BorderSide(color: edge, width: edgeWidth * scale),
                  ),
          ),
          child: child,
        ),
      ),
    );
    if (semanticLabel == null) return tile;
    return Semantics(button: onTap != null, label: semanticLabel, child: tile);
  }
}

class StadiumIconSquare extends StatelessWidget {
  const StadiumIconSquare({
    super.key,
    required this.color,
    this.icon,
    this.letter,
    this.foreground = Colors.white,
  });

  final Color color;
  final IconData? icon;
  final String? letter;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      width: 48 * scale,
      height: 48 * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border(
          bottom: BorderSide(
            color: color == StadiumColors.green ? StadiumColors.greenDark : Colors.transparent,
            width: 3 * scale,
          ),
        ),
      ),
      child: letter != null
          ? Text(letter!, style: stadiumText(scale, 20, weight: FontWeight.w600))
          : Icon(icon, color: foreground, size: 26 * scale),
    );
  }
}

class StadiumIconText extends StatelessWidget {
  const StadiumIconText({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.textColor = Colors.white,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16 * scale),
        SizedBox(width: 4 * scale),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stadiumText(scale, 14, color: textColor),
          ),
        ),
      ],
    );
  }
}

class StadiumStatTile extends StatelessWidget {
  const StadiumStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 12 * scale,
          horizontal: 8 * scale,
        ),
        decoration: BoxDecoration(
          color: KickoffColors.panel,
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Column(
          children: [
            Icon(icon, color: KickoffColors.yellow, size: 24 * scale),
            SizedBox(height: 4 * scale),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: stadiumText(scale, 24, weight: FontWeight.w600),
              ),
            ),
            Text(label, style: stadiumText(scale, 13, color: KickoffColors.muted)),
          ],
        ),
      ),
    );
  }
}

class StadiumPanel extends StatelessWidget {
  const StadiumPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(18 * scale),
      ),
      child: child,
    );
  }
}

class StadiumBanner extends StatelessWidget {
  const StadiumBanner({
    super.key,
    required this.icon,
    required this.text,
    this.error = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final bool error;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      constraints: BoxConstraints(minHeight: 48 * scale),
      decoration: BoxDecoration(
        color: error ? KickoffColors.redDark : KickoffColors.panelDark,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: error ? Colors.white : KickoffColors.yellow,
            size: 20 * scale,
          ),
          SizedBox(width: 8 * scale),
          Expanded(child: Text(text, style: stadiumText(scale, 14))),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: Size(48 * scale, 48 * scale),
              ),
              child: Text(
                actionLabel!,
                style: stadiumText(
                  scale,
                  14,
                  color: KickoffColors.yellow,
                  weight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StadiumLoading extends StatelessWidget {
  const StadiumLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: KickoffColors.yellow),
  );
}

class StadiumStatusView extends StatelessWidget {
  const StadiumStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.refresh_rounded,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final IconData actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24 * scale,
        vertical: 16 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80 * scale,
            height: 80 * scale,
            decoration: const BoxDecoration(
              color: KickoffColors.panel,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: KickoffColors.yellow, size: 38 * scale),
          ),
          SizedBox(height: 14 * scale),
          Text(
            title,
            textAlign: TextAlign.center,
            style: stadiumText(scale, 19, weight: FontWeight.w600),
          ),
          if (message.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Text(
              message,
              textAlign: TextAlign.center,
              style: stadiumText(scale, 15, color: KickoffColors.muted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 18 * scale),
            ChunkyButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
    if (compact) return content;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}

class StadiumProgress extends StatelessWidget {
  const StadiumProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      label: 'Step ${step + 1} of $total',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) SizedBox(width: 6 * scale),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 7 * scale,
                decoration: BoxDecoration(
                  color: index <= step
                      ? KickoffColors.yellow
                      : KickoffColors.panel,
                  borderRadius: BorderRadius.circular(4 * scale),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StadiumStepTitle extends StatelessWidget {
  const StadiumStepTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: stadiumText(scale, 18, weight: FontWeight.w600)),
        if (subtitle != null)
          Text(subtitle!, style: stadiumText(scale, 14, color: KickoffColors.muted)),
      ],
    );
  }
}

class StadiumSectionLabel extends StatelessWidget {
  const StadiumSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale, left: 4 * scale),
      child: Text(
        text,
        style: stadiumText(
          scale,
          14,
          color: KickoffColors.muted,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class StadiumPill extends StatelessWidget {
  const StadiumPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final fg = selected ? KickoffColors.ink : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? KickoffColors.yellow : KickoffColors.panel,
        borderRadius: BorderRadius.circular(24 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24 * scale),
          child: Container(
            constraints: BoxConstraints(
              minHeight: 48 * scale,
              minWidth: 56 * scale,
            ),
            padding: EdgeInsets.symmetric(horizontal: 14 * scale),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18 * scale, color: fg),
                  SizedBox(width: 6 * scale),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: stadiumText(scale, 15, color: fg, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StadiumFeatureTile extends StatelessWidget {
  const StadiumFeatureTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final fg = selected ? KickoffColors.ink : KickoffColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: StadiumChunkyTile(
        color: selected ? KickoffColors.yellow : KickoffColors.panel,
        edge: selected ? KickoffColors.yellowDark : KickoffColors.panelDark,
        onTap: onTap,
        radius: 16,
        padding: EdgeInsets.symmetric(
          vertical: 10 * scale,
          horizontal: 2 * scale,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 24 * scale),
            SizedBox(height: 4 * scale),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: stadiumText(scale, 13, color: fg, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StadiumDayToggle extends StatelessWidget {
  const StadiumDayToggle({
    super.key,
    required this.letter,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name ${selected ? 'open' : 'closed'}',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: selected ? KickoffColors.yellow : KickoffColors.panel,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Text(
                letter,
                style: stadiumText(
                  scale,
                  16,
                  color: selected ? KickoffColors.ink : KickoffColors.muted,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StadiumTimeButton extends StatelessWidget {
  const StadiumTimeButton({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      label: '$label at $value',
      excludeSemantics: true,
      child: Material(
        color: KickoffColors.field,
        borderRadius: BorderRadius.circular(28 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28 * scale),
          child: Container(
            constraints: BoxConstraints(minHeight: 56 * scale),
            padding: EdgeInsets.symmetric(horizontal: 14 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: KickoffColors.yellow,
                  size: 20 * scale,
                ),
                SizedBox(width: 8 * scale),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: stadiumText(scale, 17, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StadiumRoundAction extends StatelessWidget {
  const StadiumRoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.small = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final size = (small ? 40 : 52) * scale;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28 * scale,
        child: SizedBox(
          width: 48 * scale,
          height: 48 * scale,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: enabled ? KickoffColors.yellow : KickoffColors.field,
                shape: BoxShape.circle,
                border: Border(
                  bottom: BorderSide(
                    color: enabled
                        ? KickoffColors.yellowDark
                        : Colors.transparent,
                    width: 3 * scale,
                  ),
                ),
              ),
              child: Icon(
                icon,
                color: enabled ? KickoffColors.ink : KickoffColors.dim,
                size: (small ? 20 : 26) * scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StadiumCircleAction extends StatelessWidget {
  const StadiumCircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 26 * scale,
          child: SizedBox(
            width: 48 * scale,
            height: 48 * scale,
            child: Center(
              child: Container(
                width: 40 * scale,
                height: 40 * scale,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: foreground, size: 24 * scale),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StadiumLetterChip extends StatelessWidget {
  const StadiumLetterChip({
    super.key,
    required this.letter,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? KickoffColors.yellow : KickoffColors.panel,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48 * scale,
            height: 48 * scale,
            child: Center(
              child: Text(
                letter,
                style: stadiumText(
                  scale,
                  17,
                  color: selected ? KickoffColors.ink : Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StadiumBadgeButton extends StatelessWidget {
  const StadiumBadgeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RoundIconButton(
          icon: icon,
          label: count > 0 ? '$label, $count waiting' : label,
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: 4 * scale,
            top: 4 * scale,
            child: IgnorePointer(
              child: Container(
                constraints: BoxConstraints(minWidth: 20 * scale),
                height: 20 * scale,
                padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KickoffColors.red,
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: stadiumText(scale, 12, weight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class StadiumKickoffSwitch extends StatelessWidget {
  const StadiumKickoffSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KickoffColors.ink
            : KickoffColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KickoffColors.yellow
            : KickoffColors.field,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

class StadiumDashedAdd extends StatelessWidget {
  const StadiumDashedAdd({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * scale),
        child: CustomPaint(
          painter: StadiumDashedBorderPainter(radius: 18 * scale, scale: scale),
          child: SizedBox(
            height: 64 * scale,
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: KickoffColors.muted,
                size: 30 * scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StadiumDashedBorderPainter extends CustomPainter {
  const StadiumDashedBorderPainter({required this.radius, required this.scale});

  final double radius;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KickoffColors.dim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(scale),
      );
    final dash = 7 * scale;
    final gap = 5 * scale;
    for (final metric in path.computeMetrics()) {
      for (
        var distance = 0.0;
        distance < metric.length;
        distance += dash + gap
      ) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(StadiumDashedBorderPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.scale != scale;
}

class StadiumSheetBody extends StatelessWidget {
  const StadiumSheetBody({
    super.key,
    required this.title,
    required this.children,
    this.maxHeightFactor = 0.85,
  });

  final String title;
  final List<Widget> children;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16 * scale,
            10 * scale,
            16 * scale,
            12 * scale,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40 * scale,
                  height: 5 * scale,
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(3 * scale),
                  ),
                ),
              ),
              SizedBox(height: 14 * scale),
              Text(title, style: stadiumText(scale, 19, weight: FontWeight.w600)),
              SizedBox(height: 14 * scale),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class StadiumSheetOption extends StatelessWidget {
  const StadiumSheetOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: StadiumChunkyTile(
        color: KickoffColors.panel,
        edge: KickoffColors.panel,
        edgeWidth: 0,
        radius: 16,
        onTap: onTap,
        semanticLabel: label,
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 14 * scale,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color == Colors.white ? KickoffColors.yellow : color,
              size: 22 * scale,
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Text(
                label,
                style: stadiumText(scale, 16, color: color, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StadiumTextAction extends StatelessWidget {
  const StadiumTextAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: Size.fromHeight(48 * scale)),
      icon: Icon(icon, color: color, size: 20 * scale),
      label: Text(
        label,
        style: stadiumText(scale, 15, color: color, weight: FontWeight.w600),
      ),
    );
  }
}

class StadiumInfoRow extends StatelessWidget {
  const StadiumInfoRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      child: Row(
        children: [
          Icon(icon, color: KickoffColors.yellow, size: 20 * scale),
          SizedBox(width: 12 * scale),
          Expanded(child: Text(text, style: stadiumText(scale, 16))),
        ],
      ),
    );
  }
}

TextStyle stadiumText(
  double scale,
  double size, {
  Color color = Colors.white,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(color: color, fontSize: size * scale, fontWeight: weight);

ShapeBorder stadiumSheetShape(BuildContext context) => RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(22 * kickoffScale(context)),
  ),
);
