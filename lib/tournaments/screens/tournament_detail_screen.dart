import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import '../widgets/join_requests_sheet.dart';
import '../widgets/join_team_sheet.dart';
import '../widgets/confirm_action_sheet.dart';
import '../widgets/team_details_sheet.dart';
import '../widgets/team_disbanded_banner.dart';
import '../widgets/team_tile.dart';
import '../widgets/transfer_captaincy_sheet.dart';
import '../widgets/tournament_card.dart';
import '../widgets/tournament_states.dart';
import 'tournament_bracket_view.dart';
import 'tournament_standings_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({
    required this.service,
    required this.tournamentId,
    this.promptJoin = false,
    super.key,
  });

  final TournamentService service;
  final int tournamentId;

  /// Opens the join sheet once details load (from a card's "Join now").
  final bool promptJoin;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Tournament? _tournament;

  /// Team whose join request is being sent.
  int? _requestingTeamId;

  /// Hides the "team disbanded" notice while its dismissal is being saved.
  bool _disbandNoticeHidden = false;

  @override
  void initState() {
    super.initState();
    _loadTournament(promptJoin: widget.promptJoin);
  }

  /// [showLoading] is false when refreshing behind content already shown.
  Future<void> _loadTournament({
    bool promptJoin = false,
    bool showLoading = true,
  }) async {
    setState(() {
      _isLoading = showLoading;
      _error = null;
    });
    try {
      final tournament = await widget.service.getTournament(
        widget.tournamentId,
      );
      if (!mounted) return;
      setState(() {
        _tournament = tournament;
        _isLoading = false;
      });
      if (promptJoin && tournament.canJoin) await _joinWithTeamName(tournament);
    } on TournamentException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _joinWithTeamName(Tournament tournament) async {
    var joinFailed = false;
    final joined = await showJoinTeamSheet(
      context,
      tournamentName: tournament.name,
      warning: tournament.hasPendingRequest
          ? TournamentStrings.cancelPendingWarning(
              tournament.pendingRequestTeamName,
            )
          : null,
      onJoin: (teamName) async {
        try {
          final updated = await widget.service.joinTournament(
            tournament.id,
            teamName,
          );
          if (mounted) setState(() => _tournament = updated);
          return null;
        } on TournamentException catch (error) {
          joinFailed = true;
          return error.requiresSignIn
              ? TournamentStrings.SIGN_IN_TO_JOIN
              : error.message;
        }
      },
    );
    if (!mounted) return;
    if (joined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TournamentStrings.JOIN_SUCCESS)),
      );
    } else if (joinFailed) {
      // The tournament may have filled up or closed while the sheet was open.
      await _loadTournament(showLoading: false);
    }
  }

  Future<void> _requestToJoin(
    Tournament tournament,
    TournamentTeam team,
  ) async {
    if (_requestingTeamId != null) return;
    setState(() => _requestingTeamId = team.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await widget.service.requestToJoinTeam(
        tournament.id,
        team.id,
      );
      if (!mounted) return;
      setState(() {
        _tournament = updated;
        _requestingTeamId = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text(TournamentStrings.REQUEST_SENT)),
      );
    } on TournamentException catch (error) {
      if (!mounted) return;
      setState(() => _requestingTeamId = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.requiresSignIn
                ? TournamentStrings.SIGN_IN_AGAIN
                : error.message,
          ),
        ),
      );
      // The team may have filled up or the tournament closed meanwhile.
      await _loadTournament(showLoading: false);
    }
  }

  Future<void> _openTeam(Tournament tournament, TournamentTeam team) async {
    final changed = await showTeamDetailsSheet(
      context,
      service: widget.service,
      tournamentId: tournament.id,
      teamId: team.id,
    );
    if (changed && mounted) await _loadTournament(showLoading: false);
  }

  Future<void> _openJoinRequests(Tournament tournament) async {
    final changed = await showJoinRequestsSheet(
      context,
      service: widget.service,
      tournamentId: tournament.id,
    );
    if (changed && mounted) await _loadTournament(showLoading: false);
  }

  Future<void> _confirmAndLeave(Tournament tournament) async {
    var leaveFailed = false;
    Future<String?> leave() async {
      try {
        final updated = await widget.service.leaveTournament(tournament.id);
        if (mounted) setState(() => _tournament = updated);
        return null;
      } on TournamentException catch (error) {
        leaveFailed = true;
        return error.requiresSignIn
            ? TournamentStrings.SIGN_IN_TO_LEAVE
            : error.message;
      }
    }

    // Players leave their team; captains withdraw it from the tournament.
    final teamName = tournament.myTeam?.name;
    final left = tournament.isTeamPlayer && teamName != null
        ? await showLeaveTeamSheet(context, teamName: teamName, onLeave: leave)
        : await showLeaveTournamentSheet(
            context,
            tournamentName: tournament.name,
            onLeave: leave,
          );
    if (!mounted) return;
    if (left) {
      _showMessage(
        tournament.isTeamPlayer
            ? TournamentStrings.LEAVE_TEAM_SUCCESS
            : TournamentStrings.LEAVE_SUCCESS,
      );
    } else if (leaveFailed) {
      // The tournament may have started while the sheet was open.
      await _loadTournament(showLoading: false);
    }
  }

  Future<void> _transferCaptaincy(Tournament tournament) async {
    final teamId = tournament.myTeamId;
    if (teamId == null) return;
    var transferFailed = false;
    await showTransferCaptaincySheet(
      context,
      service: widget.service,
      tournamentId: tournament.id,
      teamId: teamId,
      onTransfer: (player) async {
        try {
          final updated = await widget.service.transferCaptaincy(
            tournament.id,
            player.id,
          );
          if (!mounted) return null;
          setState(() => _tournament = updated);
          // Shown here rather than after the sheet closes, so it appears
          // however the sheet goes away.
          _showMessage(TournamentStrings.transferSuccess(player.username));
          return null;
        } on TournamentException catch (error) {
          transferFailed = true;
          return _transferErrorMessage(error);
        }
      },
    );
    if (!mounted) return;
    if (transferFailed) {
      // The roster, the team or the tournament changed meanwhile.
      await _loadTournament(showLoading: false);
    }
  }

  /// App copy for the reasons the API gives; its own message otherwise.
  static String _transferErrorMessage(TournamentException error) {
    if (error.requiresSignIn) return TournamentStrings.SIGN_IN_AGAIN;
    return switch (error.code) {
      TournamentErrorCodes.TEAM_WITHDRAWN =>
        TournamentStrings.TRANSFER_TEAM_WITHDRAWN,
      TournamentErrorCodes.NOT_CAPTAIN =>
        TournamentStrings.TRANSFER_NOT_CAPTAIN,
      TournamentErrorCodes.TRANSFER_CLOSED => TournamentStrings.TRANSFER_CLOSED,
      TournamentErrorCodes.PLAYER_NOT_ON_TEAM =>
        TournamentStrings.TRANSFER_PLAYER_GONE,
      _ => error.message,
    };
  }

  /// Hides the notice at once; the API remembers it so it is not shown
  /// again. If that fails the notice comes back with the reason.
  Future<void> _dismissDisbandNotice(Tournament tournament) async {
    setState(() => _disbandNoticeHidden = true);
    try {
      await widget.service.dismissDisbandNotice(tournament.id);
    } on TournamentException catch (error) {
      if (!mounted) return;
      setState(() => _disbandNoticeHidden = false);
      _showMessage(error.message);
    }
  }

  Future<void> _confirmAndDisband(Tournament tournament) async {
    var disbandFailed = false;
    final team = tournament.myTeam;
    final disbanded = await showDisbandTeamSheet(
      context,
      teamName: team?.name ?? TournamentStrings.YOUR_TEAM,
      // The count includes the captain.
      players: (team?.players ?? 1) - 1,
      onDisband: () async {
        try {
          final updated = await widget.service.disbandTeam(tournament.id);
          if (mounted) setState(() => _tournament = updated);
          return null;
        } on TournamentException catch (error) {
          disbandFailed = true;
          return error.requiresSignIn
              ? TournamentStrings.SIGN_IN_AGAIN
              : error.message;
        }
      },
    );
    if (!mounted) return;
    if (disbanded) {
      _showMessage(TournamentStrings.DISBAND_SUCCESS);
    } else if (disbandFailed) {
      await _loadTournament(showLoading: false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    // The join sheet handles the keyboard itself; this screen has no fields.
    resizeToAvoidBottomInset: false,
    body: SafeArea(
      child: Column(
        children: [
          TournamentHeader(title: _tournament?.name ?? TournamentStrings.TITLE),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _body() {
    final error = _error;
    final tournament = _tournament;
    if (_isLoading) return const TournamentLoading();
    if (error != null || tournament == null) {
      return TournamentError(
        message: error ?? TournamentStrings.ERROR_LOAD_DETAIL,
        onRetry: _loadTournament,
      );
    }
    final scale = kickoffScale(context);
    final format = tournament.format;
    // Tabs follow the format: leagues rank teams, knockouts draw a bracket,
    // and groups + knockout show both stages.
    final tabs = <(String, Widget)>[
      (TournamentStrings.ABOUT, _AboutTab(tournament: tournament)),
      (
        TournamentStrings.TEAMS,
        _TeamsTab(
          tournament: tournament,
          requestingTeamId: _requestingTeamId,
          onRequest: (team) => _requestToJoin(tournament, team),
          onViewTeam: (team) => _openTeam(tournament, team),
        ),
      ),
      if (format.hasStandings)
        (
          TournamentStrings.STANDINGS,
          TournamentStandingsView(
            // Reload the table when joining changes the team count.
            key: ValueKey(('standings', tournament.currentTeams)),
            service: widget.service,
            tournamentId: tournament.id,
            grouped: format.hasBracket,
          ),
        ),
      if (format.hasBracket)
        (
          TournamentStrings.BRACKET,
          TournamentBracketView(
            key: ValueKey(('bracket', tournament.currentTeams)),
            service: widget.service,
            tournamentId: tournament.id,
          ),
        ),
    ];
    return DefaultTabController(
      // A different format means a different set of tabs.
      key: ValueKey(format),
      length: tabs.length,
      child: Column(
        children: [
          if (tournament.teamDisbanded && !_disbandNoticeHidden)
            Padding(
              padding: EdgeInsets.fromLTRB(
                12 * scale,
                0,
                12 * scale,
                8 * scale,
              ),
              child: TeamDisbandedBanner(
                onDismiss: () => _dismissDisbandNotice(tournament),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale),
            child: _Hero(tournament: tournament),
          ),
          SizedBox(height: 4 * scale),
          TabBar(
            // Four labels do not fit a small phone at large text, so the bar
            // scrolls instead of squeezing them.
            isScrollable: tabs.length > TournamentSizes.FIXED_TABS,
            tabAlignment: tabs.length > TournamentSizes.FIXED_TABS
                ? TabAlignment.start
                : null,
            indicatorColor: KickoffColors.yellow,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelColor: KickoffColors.yellow,
            unselectedLabelColor: KickoffColors.muted,
            labelStyle: TextStyle(
              fontSize: TournamentSizes.BODY * scale,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              for (final (label, _) in tabs)
                Tab(height: TournamentSizes.MIN_TAP * scale, text: label),
            ],
          ),
          Expanded(
            child: TabBarView(children: [for (final (_, view) in tabs) view]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12 * scale,
              8 * scale,
              12 * scale,
              12 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tournament.canManageRequests) ...[
                  _JoinRequestsButton(
                    count: tournament.pendingRequests,
                    onPressed: () => _openJoinRequests(tournament),
                  ),
                  SizedBox(height: 8 * scale),
                ],
                if (tournament.canTransfer || tournament.canDisband)
                  _CaptainActions(
                    tournament: tournament,
                    onTransfer: () => _transferCaptaincy(tournament),
                    onDisband: () => _confirmAndDisband(tournament),
                  )
                else
                  _RegistrationButton(
                    tournament: tournament,
                    onJoin: () => _joinWithTeamName(tournament),
                    onLeave: () => _confirmAndLeave(tournament),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final progress = tournament.maxTeams == 0
        ? 0.0
        : (tournament.currentTeams / tournament.maxTeams).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    return Container(
      padding: EdgeInsets.all(TournamentSizes.CARD_PADDING * scale),
      decoration: BoxDecoration(
        color: KickoffColors.blue,
        borderRadius: radius,
        border: Border(
          bottom: BorderSide(color: KickoffColors.blueDark, width: 4 * scale),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: KickoffColors.yellow,
                size: 32 * scale,
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  tournament.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Wrap(
            spacing: 8 * scale,
            runSpacing: 4 * scale,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge.forTournament(tournament),
              Text(
                TournamentStrings.dateRange(
                  tournament.startDate,
                  tournament.endDate,
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: TournamentSizes.BODY * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(6 * scale),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8 * scale,
              color: KickoffColors.yellow,
              backgroundColor: KickoffColors.blueDark,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            TournamentStrings.teamsCount(
              tournament.currentTeams,
              tournament.maxTeams,
            ),
            style: TextStyle(
              color: KickoffColors.muted,
              fontSize: TournamentSizes.CAPTION * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final prize = tournament.prize;
    return ListView(
      padding: EdgeInsets.all(12 * scale),
      children: [
        Text(
          tournament.description.isEmpty
              ? TournamentStrings.NO_DESCRIPTION
              : tournament.description,
          style: TextStyle(
            color: Colors.white,
            fontSize: TournamentSizes.BODY * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12 * scale),
        _InfoRow(
          icon: Icons.account_tree_rounded,
          label: TournamentStrings.LABEL_FORMAT,
          value: tournament.format.label,
        ),
        _InfoRow(
          icon: Icons.groups_rounded,
          label: TournamentStrings.LABEL_TEAMS,
          value: TournamentStrings.teamsCount(
            tournament.currentTeams,
            tournament.maxTeams,
          ),
        ),
        if (prize != null && prize.isNotEmpty)
          _InfoRow(
            icon: Icons.emoji_events_rounded,
            label: TournamentStrings.LABEL_PRIZE,
            value: prize,
          ),
        if (tournament.location.isNotEmpty)
          _InfoRow(
            icon: Icons.place_rounded,
            label: TournamentStrings.LABEL_LOCATION,
            value: tournament.location,
          ),
        if (tournament.createdBy.isNotEmpty)
          _InfoRow(
            icon: Icons.person_rounded,
            label: TournamentStrings.LABEL_ORGANIZER,
            value: tournament.createdBy,
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      margin: EdgeInsets.only(bottom: 6 * scale),
      constraints: BoxConstraints(minHeight: TournamentSizes.MIN_TAP * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(
          TournamentSizes.CARD_RADIUS * scale,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: KickoffColors.yellow, size: 20 * scale),
          SizedBox(width: 10 * scale),
          Text(
            label,
            style: TextStyle(
              color: KickoffColors.muted,
              fontSize: TournamentSizes.BODY * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.white,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamsTab extends StatelessWidget {
  const _TeamsTab({
    required this.tournament,
    required this.requestingTeamId,
    required this.onRequest,
    required this.onViewTeam,
  });

  final Tournament tournament;
  final int? requestingTeamId;
  final ValueChanged<TournamentTeam> onRequest;
  final ValueChanged<TournamentTeam> onViewTeam;

  @override
  Widget build(BuildContext context) {
    final teams = tournament.teams;
    if (teams.isEmpty) {
      return const TournamentEmpty(
        icon: Icons.groups_rounded,
        title: TournamentStrings.TEAMS,
        message: TournamentStrings.EMPTY_TEAMS,
      );
    }
    final scale = kickoffScale(context);
    return ListView.separated(
      padding: EdgeInsets.all(12 * scale),
      itemCount: teams.length,
      separatorBuilder: (_, _) => SizedBox(height: 6 * scale),
      itemBuilder: (context, index) {
        final team = teams[index];
        return TeamTile(
          team: team,
          tournament: tournament,
          busy: requestingTeamId == team.id,
          onRequest: () => onRequest(team),
          onViewTeam: () => onViewTeam(team),
        );
      },
    );
  }
}

/// Opens the captain's pending requests, with a count badge.
class _JoinRequestsButton extends StatelessWidget {
  const _JoinRequestsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final radius = BorderRadius.circular(TournamentSizes.CARD_RADIUS * scale);
    return Semantics(
      button: true,
      label: TournamentStrings.joinRequestsLabel(count),
      excludeSemantics: true,
      child: Material(
        color: KickoffColors.panel,
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('tournament_join_requests'),
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: TournamentSizes.MIN_TAP * scale,
            ),
            padding: EdgeInsets.symmetric(horizontal: 14 * scale),
            child: Row(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  color: KickoffColors.yellow,
                  size: 22 * scale,
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Text(
                    TournamentStrings.JOIN_REQUESTS,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TournamentSizes.BODY * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (count > 0)
                  Container(
                    constraints: BoxConstraints(minWidth: 24 * scale),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * scale,
                      vertical: 2 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: KickoffColors.yellow,
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                    child: Text(
                      TournamentStrings.requestsBadge(count),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KickoffColors.ink,
                        fontSize: TournamentSizes.CAPTION * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                SizedBox(width: 4 * scale),
                Icon(
                  Icons.chevron_right_rounded,
                  color: KickoffColors.muted,
                  size: 22 * scale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Join, leave, or the reason neither is possible.
class _RegistrationButton extends StatelessWidget {
  const _RegistrationButton({
    required this.tournament,
    required this.onJoin,
    required this.onLeave,
  });

  final Tournament tournament;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (tournament.canLeave) {
      return ChunkyButton(
        key: const ValueKey('tournament_leave'),
        label: tournament.isTeamPlayer
            ? TournamentStrings.LEAVE_TEAM
            : TournamentStrings.LEAVE,
        icon: Icons.logout_rounded,
        onPressed: onLeave,
        backgroundColor: KickoffColors.panel,
        bottomColor: KickoffColors.panelDark,
        foregroundColor: TournamentColors.ERROR_TEXT,
      );
    }
    if (tournament.hasTeam && !tournament.joined) {
      return const ChunkyButton(
        label: TournamentStrings.TEAM_MEMBER,
        icon: Icons.groups_rounded,
        onPressed: null,
        backgroundColor: KickoffColors.panel,
        bottomColor: KickoffColors.panelDark,
        foregroundColor: TournamentColors.SUCCESS_TEXT,
      );
    }
    // Once the tournament starts, joined teams stay in it.
    if (tournament.joined) {
      return const ChunkyButton(
        label: TournamentStrings.JOINED,
        icon: Icons.check_rounded,
        onPressed: null,
        backgroundColor: KickoffColors.panel,
        bottomColor: KickoffColors.panelDark,
        foregroundColor: TournamentColors.SUCCESS_TEXT,
      );
    }
    if (!tournament.canJoin) {
      return ChunkyButton(
        label: tournament.isOpen
            ? TournamentStrings.FULL
            : TournamentStrings.NOT_OPEN,
        icon: Icons.block_rounded,
        onPressed: null,
        backgroundColor: KickoffColors.panel,
        bottomColor: KickoffColors.panelDark,
        foregroundColor: KickoffColors.muted,
      );
    }
    return ChunkyButton(
      key: const ValueKey('tournament_join'),
      label: TournamentStrings.JOIN,
      icon: Icons.add_rounded,
      onPressed: onJoin,
    );
  }
}

/// A captain whose team has players hands it over or disbands it instead of
/// leaving alone. Disband is the quieter, destructive option.
class _CaptainActions extends StatelessWidget {
  const _CaptainActions({
    required this.tournament,
    required this.onTransfer,
    required this.onDisband,
  });

  final Tournament tournament;
  final VoidCallback onTransfer;
  final VoidCallback onDisband;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tournament.canTransfer)
          ChunkyButton(
            key: const ValueKey('tournament_transfer'),
            label: TournamentStrings.TRANSFER_CAPTAINCY,
            icon: Icons.swap_horiz_rounded,
            onPressed: onTransfer,
            backgroundColor: KickoffColors.panel,
            bottomColor: KickoffColors.panelDark,
            foregroundColor: Colors.white,
          ),
        if (tournament.canDisband)
          TextButton.icon(
            key: const ValueKey('tournament_disband'),
            style: TextButton.styleFrom(
              foregroundColor: TournamentColors.ERROR_TEXT,
              minimumSize: Size.fromHeight(TournamentSizes.MIN_TAP * scale),
            ),
            onPressed: onDisband,
            icon: Icon(Icons.group_off_rounded, size: 20 * scale),
            label: Text(
              TournamentStrings.DISBAND_TEAM,
              style: TextStyle(
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
