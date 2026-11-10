import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../firebase/cloud_sync.dart';
import '../friends/friends_screen.dart';
import '../settings/settings_screen.dart';
import '../matches/match_controller.dart';
import '../app_route_observer.dart';
import '../matches/football_match.dart';
import '../matches/match_repository.dart';
import '../models.dart';
import '../challenges/repository/challenge_repository.dart';
import '../challenges/screens/challenges_dashboard_screen.dart';
import '../stadium/stadium_module.dart';
import '../users/country_service.dart';
import '../users/user_profile_controller.dart';
import 'edit_profile_screen.dart';
import 'people_screen.dart';
import '../security/app_lock.dart';
import '../tournaments/screens/tournaments_list_screen.dart';
import '../tournaments/services/tournament_service.dart';
import '../tournaments/widgets/requests_badge.dart';
import 'calendar_screen.dart';
import 'home_dashboard_screen.dart';
import 'kickoff_style.dart';
import 'match/match_home_screen.dart';
import 'placeholder_screen.dart';
import 'profile_screen.dart';

final _guestMatches = <FootballMatch>[
  FootballMatch(
    id: 'demo-upcoming',
    scheduledAt: DateTime.now().add(const Duration(days: 2, hours: 2)),
    stadium: 'Blue Arena',
    joinedSlots: 5,
    totalSlots: 10,
    isPublic: true,
    participation: MatchParticipation.joined,
  ),
  FootballMatch(
    id: 'demo-created',
    scheduledAt: DateTime.now().add(const Duration(days: 6, hours: 1)),
    stadium: 'North Park',
    joinedSlots: 8,
    totalSlots: 10,
    isPublic: false,
    participation: MatchParticipation.created,
  ),
  FootballMatch(
    id: 'demo-past',
    scheduledAt: DateTime.now().subtract(const Duration(days: 3)),
    stadium: 'Riverside Pitch',
    joinedSlots: 10,
    totalSlots: 10,
    isPublic: true,
    participation: MatchParticipation.created,
  ),
];



class KickoffShell extends StatefulWidget {
  const KickoffShell({
    required this.api,
    required this.user,
    required this.onLogout,
    this.isGuest = false,
    this.cloud = const NoopCloudSync(),
    this.onSwitchAccount,
    this.onForgetAccount,
    this.onAddAccount,
    this.onOpenAuth,
    this.matchRepository = const EmptyMatchRepository(),
    this.appLock,
    this.authenticator,
    super.key,
  });

  /// App lock setting and the phone check. When either is null Settings does
  /// not offer the lock.
  final AppLockSettings? appLock;
  final Authenticator? authenticator;

  final ApiClient api;
  final CloudSync cloud;

  /// Account switching from Settings → Profiles; null hides nothing, the
  /// screen simply cannot switch.
  final Future<bool> Function(int id)? onSwitchAccount;
  final Future<void> Function(int id)? onForgetAccount;
  final VoidCallback? onAddAccount;
  final UserAccount user;
  final VoidCallback onLogout;
  final bool isGuest;
  final VoidCallback? onOpenAuth;
  final MatchRepository matchRepository;

  @override
  State<KickoffShell> createState() => _KickoffShellState();
}

class _KickoffShellState extends State<KickoffShell> with RouteAware {
  int _tab = 0;
  bool _menuOpen = false;
  bool _loadingProfile = true;
  bool _loadingMatches = true;
  GamificationProfile? _profile;
  List<FootballMatch> _matches = const [];
  String? _profileError;
  String? _matchesError;
  bool _showHistoryOnCalendar = false;
  late final _matchController = MatchController(
    uid: widget.isGuest ? 'guest' : '${widget.user.id}',
    username: widget.isGuest ? 'Guest' : widget.user.username,
    cloud: widget.isGuest ? const NoopCloudSync() : widget.cloud,
  );
  static final _noChanges = ChangeNotifier();
  final _countries = CountryService();

  /// The signed-in player's profile on this phone. Guests have none.
  late final UserProfileController? _profileController = widget.isGuest
      ? null
      : UserProfileController(
          uid: '${widget.user.id}',
          accountUsername: widget.user.username,
          email: widget.user.email,
          cloud: widget.cloud,
        );

  /// Join requests waiting for this captain; the home banner hides at zero.
  int _pendingJoinRequests = 0;
  int _latestPendingLoad = 0;
  late final _tournamentService = TournamentService(widget.api);
  ModalRoute<void>? _route;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshIfHomeVisible);
    _refreshProfile();
    _loadPendingJoinRequests();
    _loadMatches();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _lifecycle.dispose();
    _profileController?.dispose();
    super.dispose();
  }

  /// Back from any screen pushed above the shell (tournaments, friends,
  /// awards...): requests may have arrived or been answered meanwhile.
  @override
  void didPopNext() => _refreshIfHomeVisible();

  /// The banner lives on the Home tab, so only that tab refreshes it.
  void _refreshIfHomeVisible() {
    if (_tab == 0 && (_route?.isCurrent ?? true)) _loadPendingJoinRequests();
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

  /// The banner is a shortcut, so a failure only hides it; the service logs
  /// the cause and the tournaments screens show their own errors.
  Future<void> _loadPendingJoinRequests() async {
    // Only the latest load may update the banner, so a slow earlier answer
    // cannot overwrite a newer count.
    final load = ++_latestPendingLoad;
    try {
      final count = await _tournamentService.getPendingRequestCount();
      if (mounted && load == _latestPendingLoad) {
        setState(() => _pendingJoinRequests = count);
      }
    } on TournamentException {
      if (mounted && load == _latestPendingLoad) {
        setState(() => _pendingJoinRequests = 0);
      }
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([_refreshProfile(), _loadPendingJoinRequests()]);
  }

  Future<void> _loadMatches() async {
    _matchController.load();
    setState(() {
      _loadingMatches = true;
      _matchesError = null;
    });
    try {
      final matches = widget.isGuest
          ? _guestMatches
          : await widget.matchRepository.listMatches();
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

  void _handleBallMenuSelect(String title, IconData icon) {
    setState(() => _menuOpen = false);
    if (title == 'Challenge') {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChallengesDashboardScreen(
            repository: SqliteChallengeRepository(),
            user: widget.user,
            isGuest: widget.isGuest,
          ),
        ),
      );
    } else {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => title == 'Match'
              ? MatchHomeScreen(controller: _matchController)
              : PlaceholderScreen(title: title, icon: icon),
        ),
      );
    }
  }

  /// The banner refreshes in [didPopNext] once the tournaments close.
  void _openTournaments() {
    setState(() => _menuOpen = false);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TournamentsListScreen(service: _tournamentService),
      ),
    );
  }

  void _openFriends() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendsScreen(api: widget.api, user: widget.user),
      ),
    );
  }

  void _showSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          api: widget.api,
          user: widget.user,
          onLogout: widget.onLogout,
          onEditProfile: _profileController?.profile == null
              ? null
              : _editProfile,
          appLock: widget.appLock,
          onSetAppLock: widget.appLock != null && widget.authenticator != null
              ? _setAppLock
              : null,
          onSwitchAccount: widget.onSwitchAccount,
          onForgetAccount: widget.onForgetAccount,
          onAddAccount: widget.onAddAccount,
          onOpenPeople: _profileController == null ? null : _openPeople,
          onResetProfile: _profileController == null
              ? null
              : _confirmResetProfile,
        ),
      ),
    );
  }

  void _openAwards() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AwardsScreen(
          profile: _profile,
          localAwards: widget.isGuest ? const [] : _matchController.awards,
        ),
      ),
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
    // Back on Home: the banner may be out of date.
    if (_tab == 0) _loadPendingJoinRequests();
  }

  Widget _screen() => switch (_tab) {
    0 => HomeDashboardScreen(
      user: widget.user,
      profile: _profile,
      loading: _loadingProfile,
      loadError: _profileError,
      nextMatch: _nextMatch,
      onRetry: _refreshHome,
      onOpenBallMenu: () => setState(() => _menuOpen = true),
      tournamentBanner: _pendingJoinRequests > 0
          ? PendingRequestsBanner(
              count: _pendingJoinRequests,
              onOpen: _openTournaments,
            )
          : null,
    ),
    1 => ListenableBuilder(
      listenable: _matchController,
      builder: (context, _) => CalendarScreen(
        // Matches made on this phone first, then the ones from the repository.
        matches: [..._matchController.calendarMatches, ..._matches],
        loading: _loadingMatches,
        loadError: _matchesError,
        onRetry: _loadMatches,
        initialHistory: _showHistoryOnCalendar,
        key: ValueKey(_showHistoryOnCalendar),
      ),
    ),
    _ => ListenableBuilder(
      listenable: Listenable.merge([
        _profileController ?? _noChanges,
        _matchController,
      ]),
      builder: (context, _) {
        final local = _profileController?.profile;
        return ProfileScreen(
          user: widget.user,
          profile: _profile,
          localProfile: local,
          countries: _countries,
          matchesPlayed: _matchController.stats?.played,
          matchesHosted: _matchController.stats?.hosted,
          // Only offered once the phone copy loaded; guests have none.
          onEditProfile: local == null ? null : _editProfile,
          onHistory: _openHistory,
          onAwards: _openAwards,
          onFriends: _openFriends,
          onSettings: _showSettings,
          onStadiums: _openStadiums,
        );
      },
    ),
  };

  Future<void> _confirmResetProfile() async {
    final controller = _profileController;
    if (controller == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset profile?'),
        content: const Text(
          'This deletes your bio, position and avatar from this phone and '
          'starts again from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await controller.resetProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done ? 'Profile reset.' : controller.lastError ?? 'Reset failed.',
        ),
      ),
    );
  }

  /// Turns the lock on or off. Both need the phone check to pass first, so a
  /// stranger holding an unlocked phone cannot switch it off.
  Future<bool> _setAppLock(bool on) async {
    final settings = widget.appLock;
    final auth = widget.authenticator;
    if (settings == null || auth == null) return false;
    String? problem;
    if (on && !await auth.isAvailable()) {
      problem = 'Set up a fingerprint or screen lock on this phone first.';
    } else if (!await auth.authenticate(
      on ? 'Turn on the app lock' : 'Turn off the app lock',
    )) {
      problem = 'The check did not pass, so the lock was not changed.';
    }
    if (problem != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(problem)));
      }
      return false;
    }
    await settings.setEnabled(on);
    return true;
  }

  void _openPeople() {
    final controller = _profileController;
    if (controller == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PeopleScreen(controller: controller),
      ),
    );
  }

  Future<void> _editProfile() async {
    final controller = _profileController;
    if (controller == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EditProfileScreen(controller: controller, countries: _countries),
      ),
    );
  }

  void _openStadiums() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StadiumModule(
          isGuest: widget.isGuest,
          onSignIn: widget.onOpenAuth,
        ),
      ),
    );
  }

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
              onSelect: _handleBallMenuSelect,
              onTournaments: _openTournaments,
            ),
        ],
      ),
      bottomNavigationBar: KickoffBottomBar(
        selectedTab: _showHistoryOnCalendar ? 1 : _tab,
        menuOpen: _menuOpen,
        onCalendarTap: _selectCalendar,
        onBallTap: () => setState(() => _menuOpen = !_menuOpen),
        onProfileTap: () {
          // The phone copy of the profile loads the first time it is needed.
          _profileController?.load();
          _matchController.load();
          setState(() {
            _menuOpen = false;
            _tab = 2;
          });
        },
      ),
    ),
  );
}

class _BallMenuOverlay extends StatelessWidget {
  const _BallMenuOverlay({
    required this.onDismiss,
    required this.onSelect,
    required this.onTournaments,
  });

  final VoidCallback onDismiss;
  final void Function(String title, IconData icon) onSelect;
  final VoidCallback onTournaments;

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
              onTap: onTournaments,
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
