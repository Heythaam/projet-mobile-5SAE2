import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../home_screen.dart';
import '../matches/football_match.dart';
import '../matches/match_repository.dart';
import '../models.dart';
import 'calendar_screen.dart';
import 'home_dashboard_screen.dart';
import 'kickoff_style.dart';
import 'placeholder_screen.dart';
import 'profile_screen.dart';

class KickoffShell extends StatefulWidget {
  const KickoffShell({
    required this.api,
    required this.user,
    required this.onLogout,
    this.matchRepository = const EmptyMatchRepository(),
    super.key,
  });

  final ApiClient api;
  final UserAccount user;
  final VoidCallback onLogout;
  final MatchRepository matchRepository;

  @override
  State<KickoffShell> createState() => _KickoffShellState();
}

class _KickoffShellState extends State<KickoffShell> {
  int _tab = 0;
  bool _menuOpen = false;
  bool _loadingProfile = true;
  bool _loadingMatches = true;
  GamificationProfile? _profile;
  List<FootballMatch> _matches = const [];
  String? _profileError;
  String? _matchesError;
  bool _showHistoryOnCalendar = false;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
    _loadMatches();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await widget.api.getGamificationProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = error.toString();
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadMatches() async {
    setState(() {
      _loadingMatches = true;
      _matchesError = null;
    });
    try {
      final matches = await widget.matchRepository.listMatches();
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loadingMatches = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _matchesError = error.toString();
        _loadingMatches = false;
      });
    }
  }

  void _openPlaceholder(String title, IconData icon) {
    setState(() => _menuOpen = false);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlaceholderScreen(title: title, icon: icon),
      ),
    );
  }

  void _openFriends() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(
          api: widget.api,
          user: widget.user,
          onLogout: widget.onLogout,
          showNavigation: false,
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: KickoffColors.panelDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22 * kickoffScale(context)),
        ),
      ),
      builder: (context) {
        final scale = kickoffScale(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16 * scale,
              18 * scale,
              16 * scale,
              12 * scale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12 * scale),
                ChunkyButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  backgroundColor: KickoffColors.red,
                  bottomColor: KickoffColors.redDark,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onLogout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAwards() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => AwardsScreen(profile: _profile)),
    );
  }

  void _openHistory() {
    setState(() {
      _showHistoryOnCalendar = true;
      _tab = 1;
      _menuOpen = false;
    });
  }

  void _selectCalendar() {
    setState(() {
      _menuOpen = false;
      _tab = _tab == 1 ? 0 : 1;
      _showHistoryOnCalendar = false;
    });
  }

  Widget _screen() => switch (_tab) {
    0 => HomeDashboardScreen(
      user: widget.user,
      profile: _profile,
      loading: _loadingProfile,
      loadError: _profileError,
      nextMatch: _nextMatch,
      onRetry: _refreshProfile,
      onOpenBallMenu: () => setState(() => _menuOpen = true),
    ),
    1 => CalendarScreen(
      matches: _matches,
      loading: _loadingMatches,
      loadError: _matchesError,
      onRetry: _loadMatches,
      initialHistory: _showHistoryOnCalendar,
      key: ValueKey(_showHistoryOnCalendar),
    ),
    _ => ProfileScreen(
      user: widget.user,
      profile: _profile,
      onHistory: _openHistory,
      onAwards: _openAwards,
      onFriends: _openFriends,
      onSettings: _showSettings,
    ),
  };

  FootballMatch? get _nextMatch {
    final now = DateTime.now();
    final upcoming =
        _matches.where((match) => !match.scheduledAt.isBefore(now)).toList()
          ..sort(
            (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
          );
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: KickoffColors.bg,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: KickoffColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: KickoffColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _screen()),
          if (_menuOpen)
            _BallMenuOverlay(
              onDismiss: () => setState(() => _menuOpen = false),
              onSelect: _openPlaceholder,
            ),
        ],
      ),
      bottomNavigationBar: KickoffBottomBar(
        selectedTab: _showHistoryOnCalendar ? 1 : _tab,
        menuOpen: _menuOpen,
        onCalendarTap: _selectCalendar,
        onBallTap: () => setState(() => _menuOpen = !_menuOpen),
        onProfileTap: () => setState(() {
          _menuOpen = false;
          _tab = 2;
        }),
      ),
    ),
  );
}

class _BallMenuOverlay extends StatelessWidget {
  const _BallMenuOverlay({required this.onDismiss, required this.onSelect});

  final VoidCallback onDismiss;
  final void Function(String title, IconData icon) onSelect;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: ColoredBox(
                color: KickoffColors.ink.withValues(alpha: 0.82),
                child: const SizedBox.expand(),
              ),
            ),
            _positionedOption(
              width: constraints.maxWidth,
              scale: scale,
              leftFraction: 0.2,
              bottom: 90 * scale,
              label: 'Challenge',
              icon: Icons.flash_on_rounded,
              color: KickoffColors.blue,
              bottomColor: KickoffColors.blueDark,
              foreground: Colors.white,
              delay: 0,
              onTap: () => onSelect('Challenge', Icons.flash_on_rounded),
            ),
            _positionedOption(
              width: constraints.maxWidth,
              scale: scale,
              leftFraction: 0.5,
              bottom: 142 * scale,
              label: 'Match',
              icon: Icons.sports_soccer_rounded,
              color: KickoffColors.yellow,
              bottomColor: KickoffColors.yellowDark,
              foreground: KickoffColors.ink,
              delay: 50,
              onTap: () => onSelect('Match', Icons.sports_soccer_rounded),
            ),
            _positionedOption(
              width: constraints.maxWidth,
              scale: scale,
              leftFraction: 0.8,
              bottom: 90 * scale,
              label: 'Tournament',
              icon: Icons.emoji_events_rounded,
              color: KickoffColors.blue,
              bottomColor: KickoffColors.blueDark,
              foreground: Colors.white,
              delay: 100,
              onTap: () => onSelect('Tournament', Icons.emoji_events_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionedOption({
    required double width,
    required double scale,
    required double leftFraction,
    required double bottom,
    required String label,
    required IconData icon,
    required Color color,
    required Color bottomColor,
    required Color foreground,
    required int delay,
    required VoidCallback onTap,
  }) {
    final optionWidth = label == 'Match' ? 112 * scale : 96 * scale;
    return Positioned(
      left: width * leftFraction - optionWidth / 2,
      bottom: bottom,
      child: _ArcOption(
        label: label,
        icon: icon,
        color: color,
        bottomColor: bottomColor,
        foreground: foreground,
        delay: delay,
        onTap: onTap,
      ),
    );
  }
}

class _ArcOption extends StatefulWidget {
  const _ArcOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.bottomColor,
    required this.foreground,
    required this.delay,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bottomColor;
  final Color foreground;
  final int delay;
  final VoidCallback onTap;

  @override
  State<_ArcOption> createState() => _ArcOptionState();
}

class _ArcOptionState extends State<_ArcOption> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final diameter = widget.label == 'Match' ? 88 * scale : 72 * scale;
    return AnimatedScale(
      scale: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: widget.label == 'Match' ? 112 * scale : 96 * scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: widget.color,
              borderRadius: BorderRadius.circular(diameter / 2),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(diameter / 2),
                child: Container(
                  width: diameter,
                  height: diameter,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(diameter / 2),
                    border: Border(
                      bottom: BorderSide(
                        color: widget.bottomColor,
                        width: 5 * scale,
                      ),
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.foreground,
                    size: 32 * scale,
                  ),
                ),
              ),
            ),
            SizedBox(height: 5 * scale),
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
