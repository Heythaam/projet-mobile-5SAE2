import 'package:flutter/material.dart';

import '../../screens/kickoff_style.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../tournament_constants.dart';
import '../widgets/tournament_card.dart';
import '../widgets/tournament_states.dart';
import 'tournament_detail_screen.dart';

class TournamentsListScreen extends StatefulWidget {
  const TournamentsListScreen({required this.service, super.key});

  final TournamentService service;

  @override
  State<TournamentsListScreen> createState() => _TournamentsListScreenState();
}

class _TournamentsListScreenState extends State<TournamentsListScreen> {
  static const _filters = <TournamentStatus?>[
    null,
    TournamentStatus.active,
    TournamentStatus.upcoming,
    TournamentStatus.finished,
  ];

  final _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  List<Tournament> _tournaments = const [];
  TournamentStatus? _filter;
  int _latestRequest = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  /// Shows the skeleton only when asked, so returning from a detail page
  /// refreshes the list in place.
  Future<void> _loadTournaments({bool showSkeleton = true}) async {
    // Only the latest request may update the screen, so a slow response for
    // an earlier filter cannot overwrite the current one.
    final request = ++_latestRequest;
    setState(() {
      _isLoading = showSkeleton;
      _error = null;
    });
    try {
      final tournaments = await widget.service.getTournaments(status: _filter);
      if (!mounted || request != _latestRequest) return;
      setState(() {
        _tournaments = tournaments;
        _isLoading = false;
      });
    } on TournamentException catch (error) {
      if (!mounted || request != _latestRequest) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  void _selectFilter(TournamentStatus? filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _loadTournaments();
  }

  void _toggleSearch() {
    setState(() => _isSearching = !_isSearching);
    if (!_isSearching) _searchController.clear();
  }

  Future<void> _openTournament(
    Tournament tournament, {
    bool promptJoin = false,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TournamentDetailScreen(
          service: widget.service,
          tournamentId: tournament.id,
          promptJoin: promptJoin,
        ),
      ),
    );
    // Join state or team counts may have changed on the detail screen.
    if (mounted) _loadTournaments(showSkeleton: false);
  }

  List<Tournament> get _visibleTournaments {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _tournaments;
    return _tournaments
        .where((tournament) => tournament.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            TournamentHeader(
              title: TournamentStrings.TITLE,
              action: TournamentIconButton(
                icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
                tooltip: _isSearching
                    ? TournamentStrings.CLOSE_SEARCH
                    : TournamentStrings.SEARCH,
                onPressed: _toggleSearch,
              ),
            ),
            if (_isSearching)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12 * scale,
                  0,
                  12 * scale,
                  8 * scale,
                ),
                child: PillField(
                  controller: _searchController,
                  hint: TournamentStrings.SEARCH_HINT,
                  icon: Icons.search_rounded,
                  textInputAction: TextInputAction.search,
                ),
              ),
            SizedBox(
              height: (TournamentSizes.MIN_TAP + 8) * scale,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => SizedBox(width: 6 * scale),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  return Center(
                    child: _FilterChip(
                      label: filter?.label ?? TournamentStrings.FILTER_ALL,
                      selected: filter == _filter,
                      onTap: () => _selectFilter(filter),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 6 * scale),
            Expanded(child: _body(scale)),
          ],
        ),
      ),
    );
  }

  Widget _body(double scale) {
    final error = _error;
    if (_isLoading) return const TournamentSkeletonList();
    if (error != null) {
      return TournamentError(message: error, onRetry: _loadTournaments);
    }
    final tournaments = _visibleTournaments;
    if (tournaments.isEmpty) {
      final searching = _tournaments.isNotEmpty;
      return TournamentEmpty(
        icon: searching ? Icons.search_off_rounded : Icons.emoji_events_rounded,
        title: searching
            ? TournamentStrings.EMPTY_SEARCH
            : TournamentStrings.EMPTY_LIST,
        message: searching
            ? TournamentStrings.EMPTY_SEARCH_HINT
            : TournamentStrings.EMPTY_LIST_HINT,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadTournaments(showSkeleton: false),
      color: KickoffColors.ink,
      backgroundColor: KickoffColors.yellow,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          12 * scale,
          4 * scale,
          12 * scale,
          16 * scale,
        ),
        itemCount: tournaments.length,
        separatorBuilder: (_, _) => SizedBox(height: 8 * scale),
        itemBuilder: (context, index) {
          final tournament = tournaments[index];
          return TournamentCard(
            tournament: tournament,
            onTap: () => _openTournament(tournament),
            onJoin: () => _openTournament(tournament, promptJoin: true),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final radius = BorderRadius.circular(TournamentSizes.MIN_TAP / 2 * scale);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? KickoffColors.yellow : KickoffColors.panel,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: TournamentSizes.MIN_TAP * scale,
            ),
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? KickoffColors.ink : KickoffColors.muted,
                fontSize: TournamentSizes.BODY * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
