import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

double kickoffScale(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 360).clamp(1.0, 1.3);

abstract final class KickoffColors {
  static const bg = Color(0xFF1A1A4E);
  static const panel = Color(0xFF2D3A7A);
  static const panelDark = Color(0xFF232D63);
  static const blue = Color(0xFF0B5FE8);
  static const blueDark = Color(0xFF0A3F9C);
  static const yellow = Color(0xFFFFD21F);
  static const yellowDark = Color(0xFFC9A000);
  static const ink = Color(0xFF0A0A2E);
  static const muted = Color(0xFFB9C3EE);
  static const dim = Color(0xFF8D99D6);
  static const field = Color(0xFF3D4C7C);
  static const orange = Color(0xFFFFA24A);
  static const red = Color(0xFFE24B4A);
  static const redDark = Color(0xFFA32D2D);
}

class ArcadeBackdrop extends StatelessWidget {
  const ArcadeBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: KickoffColors.bg, child: child);
}

class KickoffLogoTile extends StatelessWidget {
  const KickoffLogoTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      width: 56 * scale,
      height: 56 * scale,
      decoration: BoxDecoration(
        color: KickoffColors.yellow,
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border(
          left: BorderSide(color: KickoffColors.ink, width: 3 * scale),
          top: BorderSide(color: KickoffColors.ink, width: 3 * scale),
          right: BorderSide(color: KickoffColors.ink, width: 3 * scale),
          bottom: BorderSide(color: KickoffColors.ink, width: 6 * scale),
        ),
      ),
      child: Icon(
        Icons.sports_soccer_rounded,
        size: 32 * scale,
        color: KickoffColors.ink,
      ),
    );
  }
}

class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = KickoffColors.yellow,
    this.bottomColor = KickoffColors.yellowDark,
    this.foregroundColor = KickoffColors.ink,
    this.busy = false,
    this.showIcon = true,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color bottomColor;
  final Color foregroundColor;
  final bool busy;
  final bool showIcon;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: GestureDetector(
        onTapDown: widget.onPressed == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.onPressed == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Transform.translate(
          offset: Offset(0, (_pressed ? 2 : 0) * scale),
          child: Container(
            height: 56 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(28 * scale),
              border: Border(
                bottom: BorderSide(
                  color: widget.bottomColor,
                  width: (_pressed ? 2 : 4) * scale,
                ),
              ),
            ),
            child: widget.busy
                ? SizedBox(
                    width: 20 * scale,
                    height: 20 * scale,
                    child: CircularProgressIndicator(
                      strokeWidth: 2 * scale,
                      color: widget.foregroundColor,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.showIcon) ...[
                        Icon(
                          widget.icon,
                          size: 24 * scale,
                          color: widget.foregroundColor,
                        ),
                        SizedBox(width: 6 * scale),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.foregroundColor,
                            fontSize: 17 * scale,
                            fontWeight: FontWeight.w600,
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

class PillField extends StatelessWidget {
  const PillField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
    this.enabled = true,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16 * scale,
        fontWeight: FontWeight.w500,
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      enabled: enabled,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: KickoffColors.muted,
          fontSize: 16 * scale,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: KickoffColors.yellow, size: 22 * scale),
        suffixIcon: suffix,
        filled: true,
        fillColor: KickoffColors.field,
        contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale),
        constraints: BoxConstraints(minHeight: 56 * scale),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28 * scale),
          borderSide: BorderSide(color: KickoffColors.ink, width: 2 * scale),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28 * scale),
          borderSide: BorderSide(color: KickoffColors.ink, width: 2 * scale),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28 * scale),
          borderSide: BorderSide(color: KickoffColors.ink, width: 2 * scale),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28 * scale),
          borderSide: BorderSide(color: KickoffColors.red, width: 2 * scale),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28 * scale),
          borderSide: BorderSide(color: KickoffColors.red, width: 2 * scale),
        ),
        errorStyle: TextStyle(
          color: Color(0xFFFFB7AB),
          fontSize: 13 * scale,
          fontWeight: FontWeight.w500,
        ),
        errorMaxLines: 2,
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      constraints: BoxConstraints(minHeight: 36 * scale),
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16 * scale),
          SizedBox(width: 3 * scale),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class SlotDots extends StatelessWidget {
  const SlotDots({required this.joined, required this.total, super.key});

  final int joined;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < total.clamp(0, 20); index++) ...[
          if (index > 0) SizedBox(width: 3 * scale),
          Container(
            width: 9 * scale,
            height: 9 * scale,
            decoration: BoxDecoration(
              color: index < joined ? KickoffColors.yellow : Colors.transparent,
              shape: BoxShape.circle,
              border: index < joined
                  ? null
                  : Border.all(color: KickoffColors.dim, width: 1.5 * scale),
            ),
          ),
        ],
        SizedBox(width: 5 * scale),
        Text(
          '$joined/$total',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 48,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56 * scale,
              height: 56 * scale,
              child: Center(
                child: Container(
                  width: size * scale,
                  height: size * scale,
                  decoration: BoxDecoration(
                    color: selected
                        ? KickoffColors.yellow
                        : KickoffColors.panel,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24 * scale,
                    color: selected ? KickoffColors.ink : KickoffColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KickoffBottomBar extends StatelessWidget {
  const KickoffBottomBar({
    required this.selectedTab,
    required this.menuOpen,
    required this.onCalendarTap,
    required this.onBallTap,
    required this.onProfileTap,
    super.key,
  });

  final int selectedTab;
  final bool menuOpen;
  final VoidCallback onCalendarTap;
  final VoidCallback onBallTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: menuOpen ? KickoffColors.panelDark : KickoffColors.panel,
      child: SizedBox(
        height: 68 * scale + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 68 * scale,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavButton(
                    icon: Icons.calendar_month_rounded,
                    label: 'Calendar',
                    selected: selectedTab == 1,
                    muted: menuOpen,
                    onPressed: onCalendarTap,
                  ),
                  SizedBox(width: 88 * scale),
                  _NavButton(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    selected: selectedTab == 2,
                    muted: menuOpen,
                    onPressed: onProfileTap,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -44 * scale,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  label: menuOpen ? 'Close ball menu' : 'Open ball menu',
                  child: Tooltip(
                    message: menuOpen ? 'Close ball menu' : 'Open ball menu',
                    child: InkResponse(
                      onTap: onBallTap,
                      radius: 50 * scale,
                      child: SizedBox(
                        width: 88 * scale,
                        height: 88 * scale,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 11 * scale,
                              child: Container(
                                width: 76 * scale,
                                height: 76 * scale,
                                decoration: BoxDecoration(
                                  color: menuOpen
                                      ? KickoffColors.redDark
                                      : KickoffColors.yellowDark,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Container(
                              width: 76 * scale,
                              height: 76 * scale,
                              decoration: BoxDecoration(
                                color: menuOpen
                                    ? KickoffColors.red
                                    : KickoffColors.yellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: KickoffColors.bg,
                                  width: 4 * scale,
                                ),
                              ),
                              child: AnimatedRotation(
                                turns: menuOpen ? 0.25 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  menuOpen
                                      ? Icons.close_rounded
                                      : Icons.sports_soccer_rounded,
                                  color: menuOpen
                                      ? Colors.white
                                      : KickoffColors.ink,
                                  size: 32 * scale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.muted,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: IconButton(
          onPressed: onPressed,
          iconSize: 28 * scale,
          constraints: BoxConstraints(
            minWidth: 56 * scale,
            minHeight: 56 * scale,
          ),
          icon: Icon(
            icon,
            color: selected && !muted
                ? KickoffColors.yellow
                : KickoffColors.muted.withValues(alpha: muted ? 0.4 : 1),
          ),
        ),
      ),
    );
  }
}
