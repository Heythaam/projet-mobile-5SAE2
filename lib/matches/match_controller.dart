import 'package:flutter/material.dart';

import '../local/local_database.dart';
import '../local/match_local_store.dart';
import '../screens/match/match_mock_data.dart';

typedef MatchStoreOpener = Future<MatchLocalStore> Function();

/// Match state for the Match screens, saved on the phone with SQFlite.
///
/// Reads are synchronous and come from a cache filled by [load]; every write
/// goes to the store first and then refreshes the cache. Matches live on this
/// phone only until Firebase sync exists.
class MatchController extends ChangeNotifier {
  MatchController({
    required this.uid,
    required this.username,
    MatchStoreOpener? openStore,
  }) : _openStore = openStore ?? _openDefaultStore;

  /// The signed-in player. Local ids are strings so Firebase uids fit later.
  final String uid;
  final String username;
  final MatchStoreOpener _openStore;

  // Placeholders the Match home screen already showed. Real values must come
  // from the API once XP is wired.
  static const level = 1;
  static const streak = 1;
  static const energy = 50;

  // Stadiums are still sample data until the Stadium module has a player
  // booking screen.
  final List<MatchStadiumData> stadiums = matchStadiums;

  MatchLocalStore? _store;
  Future<void>? _loading;
  Map<String, LocalMatch> _byCode = const {};
  MatchHomeMatch? upcomingMatch;

  /// Message for the last failed action, ready to show to the player.
  String? lastError;
  bool loaded = false;

  String get usernameInitial => _initial(username);

  static Future<MatchLocalStore> _openDefaultStore() async =>
      MatchLocalStore(await LocalDatabase.open());

  /// Opens the database once and fills the cache. Safe to call again.
  Future<void> load() => _loading ??= _refresh().whenComplete(() {
    loaded = true;
    notifyListeners();
  });

  Future<MatchLocalStore> _ensureStore() async =>
      _store ??= await _openStore();

  Future<void> _refresh({String? focusCode}) async {
    try {
      final store = await _ensureStore();
      final upcoming = await store.allUpcoming();
      _byCode = {for (final match in upcoming) match.code: match};
      final next = focusCode != null
          ? _byCode[focusCode]
          : await store.upcomingFor(uid);
      upcomingMatch = next == null ? null : _toHome(next);
    } catch (_) {
      lastError = 'Matches could not be loaded from this phone.';
    }
  }

  List<MatchPublicListing> get publicMatches => [
    for (final match in _byCode.values.where((match) => match.isPublic))
      MatchPublicListing(
        match: _toHome(match),
        timeLabel: _publicTime(match.scheduledAt.toLocal()),
        isToday: DateUtils.isSameDay(
          match.scheduledAt.toLocal(),
          DateTime.now(),
        ),
      ),
  ];

  MatchHomeMatch? findMatchByCode(String code) {
    final match = _byCode[code.trim().toUpperCase()];
    return match == null ? null : _toHome(match);
  }

  bool hasJoined(MatchHomeMatch match) =>
      _byCode[match.code.toUpperCase()]?.hasPlayer(uid) ?? false;

  /// Joins by code. Returns null and sets [lastError] when it cannot.
  Future<MatchHomeMatch?> joinByCode(String code) => _join(code);

  Future<MatchHomeMatch?> joinPublicMatch(MatchHomeMatch match) =>
      _join(match.code);

  Future<MatchHomeMatch?> _join(String code) async {
    lastError = null;
    try {
      final store = await _ensureStore();
      final joined = await store.join(code, uid, name: username);
      await _refresh(focusCode: joined.code);
      notifyListeners();
      return _toHome(joined);
    } on LocalMatchException catch (error) {
      if (error.error == LocalMatchError.alreadyJoined) {
        return findMatchByCode(code);
      }
      lastError = error.message;
      return null;
    }
  }

  /// Saves a new match with the player as host. Throws
  /// [LocalMatchException] when the input is not valid.
  Future<MatchHomeMatch> createMatch(CreateMatchDraft draft) async {
    final store = await _ensureStore();
    final created = await store.create(
      hostUid: uid,
      hostName: username,
      stadium: draft.stadium.name,
      scheduledAt: draft.startsAt,
      capacity: draft.stadium.players,
      isPublic: draft.visibility == 'Public',
    );
    await _refresh(focusCode: created.code);
    notifyListeners();
    return _toHome(created);
  }

  MatchHomeMatch _toHome(LocalMatch match) => MatchHomeMatch(
    scheduledAt: match.scheduledAt.toLocal(),
    stadium: match.stadium,
    players: match.players,
    capacity: match.capacity,
    isPublic: match.isPublic,
    code: match.code,
    playerSlots: [
      for (var i = 0; i < match.slots.length; i++)
        match.slots[i] == null
            ? null
            : _initial(
                match.slotNames[i] ?? '',
                fallback: match.slots[i] == uid ? username : '',
              ),
    ],
  );

  static String _initial(String name, {String fallback = ''}) {
    final text = name.trim().isEmpty ? fallback.trim() : name.trim();
    return text.isEmpty ? '?' : text.characters.first.toUpperCase();
  }

  static String _publicTime(DateTime date) {
    if (!DateUtils.isSameDay(date, DateTime.now())) {
      return const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][date.weekday - 1];
    }
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
