import 'package:flutter/material.dart';

import '../../sample_data/sample_data.dart';
import '../../models.dart';
import '../../screens/kickoff_style.dart';
import '../models/challenge_model.dart';
import '../repository/challenge_repository.dart';
import '../widgets/challenge_card.dart';
import 'create_challenge_screen.dart';

class ChallengesDashboardScreen extends StatefulWidget {
  const ChallengesDashboardScreen({
    required this.repository,
    required this.user,
    this.isGuest = false,
    super.key,
  });

  final ChallengeRepository repository;
  final UserAccount user;
  final bool isGuest;

  @override
  State<ChallengesDashboardScreen> createState() =>
      _ChallengesDashboardScreenState();
}

class _ChallengesDashboardScreenState extends State<ChallengesDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Challenge> _createdChallenges = const [];
  List<Challenge> _joinedChallenges = const [];
  List<Challenge> _browseChallenges = const [];

  bool _loading = true;
  String? _error;

  final _joinCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAllChallenges() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (sampleDataEnabled) await loadSampleChallenges(widget.repository);
      final userId = widget.user.id;
      final created = await widget.repository.getCreatedChallenges(userId);
      final joined = await widget.repository.getJoinedChallenges(userId);
      final browse = await widget.repository.getBrowseChallenges(userId);

      if (!mounted) return;
      setState(() {
        _createdChallenges = created;
        _joinedChallenges = joined;
        _browseChallenges = browse;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreateChallenge() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateChallengeScreen(
          repository: widget.repository,
          user: widget.user,
        ),
      ),
    );

    if (result == true) {
      _loadAllChallenges();
    }
  }

  Future<void> _editChallenge(Challenge challenge) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateChallengeScreen(
          repository: widget.repository,
          user: widget.user,
          initialChallenge: challenge,
        ),
      ),
    );

    if (result == true) {
      _loadAllChallenges();
    }
  }

  Future<void> _deleteChallenge(Challenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KickoffColors.panelDark,
        title: const Text('Delete Challenge?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${challenge.description}"?',
            style: const TextStyle(color: KickoffColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: KickoffColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: KickoffColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && challenge.id != null) {
      final success = await widget.repository.deleteChallenge(challenge.id!, widget.user.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge deleted.')),
        );
        _loadAllChallenges();
      }
    }
  }

  Future<void> _leaveChallenge(Challenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KickoffColors.panelDark,
        title: const Text('Quit Challenge?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to quit "${challenge.description}"?',
            style: const TextStyle(color: KickoffColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: KickoffColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: KickoffColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && challenge.id != null) {
      final success = await widget.repository.leaveChallenge(challenge.id!, widget.user.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You quit the challenge.')),
        );
        _loadAllChallenges();
      }
    }
  }

  Future<void> _joinChallenge(Challenge challenge) async {
    try {
      final success = await widget.repository.joinChallenge(
        challenge.id!,
        widget.user.id,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined challenge "${challenge.description}"!'),
            backgroundColor: KickoffColors.panelDark,
          ),
        );
        _loadAllChallenges();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join challenge or already full.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining: $e')),
      );
    }
  }

  Future<void> _showJoinCodeDialog() async {
    _joinCodeController.clear();
    final scale = kickoffScale(context);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KickoffColors.panelDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        title: Text(
          'Join Challenge by Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the unique code (e.g. KICK42) to find and join a challenge.',
              style: TextStyle(
                color: KickoffColors.muted,
                fontSize: 13 * scale,
              ),
            ),
            SizedBox(height: 12 * scale),
            PillField(
              controller: _joinCodeController,
              hint: 'e.g. KICK42',
              icon: Icons.key_rounded,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: KickoffColors.muted)),
          ),
          ChunkyButton(
            label: 'Join',
            icon: Icons.login_rounded,
            backgroundColor: KickoffColors.yellow,
            bottomColor: KickoffColors.yellowDark,
            foregroundColor: KickoffColors.ink,
            showIcon: false,
            onPressed: () async {
              final code = _joinCodeController.text.trim();
              if (code.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();

              final challenge = await widget.repository.findByJoinCode(
                code,
                widget.user.id,
              );

              if (!mounted) return;

              if (challenge == null) {
                messenger.showSnackBar(
                  SnackBar(content: Text('No challenge found with code "$code".')),
                );
              } else {
                await _joinChallenge(challenge);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);

    return ArcadeBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: KickoffColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: KickoffColors.muted),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Challenges',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.key_rounded, color: KickoffColors.yellow),
              tooltip: 'Enter Join Code',
              onPressed: _showJoinCodeDialog,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48 * scale),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16 * scale),
              decoration: BoxDecoration(
                color: KickoffColors.panelDark,
                borderRadius: BorderRadius.circular(24 * scale),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: KickoffColors.yellow,
                  borderRadius: BorderRadius.circular(24 * scale),
                ),
                labelColor: KickoffColors.ink,
                unselectedLabelColor: KickoffColors.muted,
                labelStyle: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Mine'),
                  Tab(text: 'Joined'),
                  Tab(text: 'Browse'),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: Semantics(
          button: true,
          label: 'Create Challenge',
          child: FloatingActionButton.extended(
            heroTag: 'create_challenge_fab',
            onPressed: _openCreateChallenge,
            backgroundColor: KickoffColors.yellow,
            foregroundColor: KickoffColors.ink,
            icon: const Icon(Icons.flash_on_rounded),
            label: Text(
              'Create',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15 * scale,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: KickoffColors.yellow))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Failed to load challenges.',
                            style: TextStyle(color: KickoffColors.muted, fontSize: 16 * scale),
                          ),
                          SizedBox(height: 12 * scale),
                          ChunkyButton(
                            label: 'Retry',
                            icon: Icons.refresh_rounded,
                            onPressed: _loadAllChallenges,
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildChallengeList(_createdChallenges, 'No challenges created yet.', scale),
                        _buildChallengeList(_joinedChallenges, 'No challenges joined yet.', scale),
                        _buildChallengeList(_browseChallenges, 'No challenges available.', scale),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildChallengeList(
    List<Challenge> challenges,
    String emptyMessage,
    double scale,
  ) {
    if (challenges.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllChallenges,
        color: KickoffColors.yellow,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 350 * scale,
            alignment: Alignment.center,
            padding: EdgeInsets.all(24 * scale),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flash_off_rounded,
                  size: 48 * scale,
                  color: KickoffColors.dim,
                ),
                SizedBox(height: 12 * scale),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KickoffColors.muted,
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllChallenges,
      color: KickoffColors.yellow,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16 * scale, 16 * scale, 16 * scale, 80 * scale),
        itemCount: challenges.length,
        itemBuilder: (context, index) {
          final challenge = challenges[index];
          return ChallengeCard(
            challenge: challenge,
            onJoin: () => _joinChallenge(challenge),
            onLeave: () => _leaveChallenge(challenge),
            onEdit: () => _editChallenge(challenge),
            onDelete: () => _deleteChallenge(challenge),
          );
        },
      ),
    );
  }
}
