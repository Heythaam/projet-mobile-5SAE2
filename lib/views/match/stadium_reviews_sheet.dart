import 'package:flutter/material.dart';

import '../../services/match/match_controller.dart';
import '../../services/stadium/stadium_directory.dart';
import '../../items/kickoff_style.dart';
import '../../entities/match/match_mock_data.dart';

/// Stars and comments about a real stadium. A player who booked it can rate it
/// from 1 to 5 and leave a short comment; each player keeps one review.
Future<void> showStadiumReviews(
  BuildContext context,
  MatchController controller,
  MatchStadiumData stadium,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: KickoffColors.bg,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _ReviewsSheet(controller: controller, stadium: stadium),
);

class _ReviewsSheet extends StatefulWidget {
  const _ReviewsSheet({required this.controller, required this.stadium});

  final MatchController controller;
  final MatchStadiumData stadium;

  @override
  State<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<_ReviewsSheet> {
  final _comment = TextEditingController();
  StadiumReviewSet? _set;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int _stars = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.stadium.stadiumId;
    if (id == null) return;
    try {
      final set = await widget.controller.reviewsOf(id);
      if (!mounted) return;
      final mine = set.reviews.where((r) => r.mine).firstOrNull;
      setState(() {
        _set = set;
        _loading = false;
        _error = null;
        if (mine != null && _stars == 0) {
          _stars = mine.stars;
          _comment.text = mine.comment;
        }
      });
    } on StadiumDirectoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save() async {
    final id = widget.stadium.stadiumId;
    if (id == null || _stars == 0) {
      setState(() => _error = 'Pick 1 to 5 stars first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.submitReview(
        id,
        stars: _stars,
        comment: _comment.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      await _load();
    } on StadiumDirectoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.stadium.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              set == null || set.rating == null
                  ? 'No reviews yet'
                  : '★ ${set.rating} · ${set.count} '
                        '${set.count == 1 ? 'review' : 'reviews'}',
              style: const TextStyle(color: KickoffColors.yellow),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final review in set?.reviews ?? const <StadiumReview>[])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${'★' * review.stars}${'☆' * (5 - review.stars)}  '
                          '@${review.userName}${review.mine ? ' (you)' : ''}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: review.comment.isEmpty
                            ? null
                            : Text(
                                review.comment,
                                style: const TextStyle(
                                  color: KickoffColors.muted,
                                ),
                              ),
                      ),
                    if (set != null && set.canReview) ...[
                      const Divider(),
                      const Text(
                        'Your review',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          for (var star = 1; star <= 5; star++)
                            IconButton(
                              key: ValueKey('review_star_$star'),
                              onPressed: () => setState(() => _stars = star),
                              icon: Icon(
                                star <= _stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: KickoffColors.yellow,
                                size: 32,
                              ),
                            ),
                        ],
                      ),
                      TextField(
                        key: const ValueKey('review_comment'),
                        controller: _comment,
                        maxLength: 200,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Say something about the pitch (optional)',
                        ),
                      ),
                      FilledButton(
                        key: const ValueKey('review_save'),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save review'),
                      ),
                    ] else if (set != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Book this stadium to leave a review.',
                          style: TextStyle(color: KickoffColors.muted),
                        ),
                      ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: KickoffColors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
