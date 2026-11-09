import 'package:flutter/material.dart';

import '../demo/demo_data.dart';
import '../local/local_database.dart';
import '../location/player_location.dart';
import '../local/match_local_store.dart';
import 'football_match.dart';
import '../screens/match/match_mock_data.dart';
import '../weather/weather_service.dart';
import 'stadium_directory.dart';

typedef MatchStoreOpener = Future<MatchLocalStore> Function();

/// The match was saved but its stadium slot could not be held, so the match was
/// removed again. [message] is ready to show to the player.
class MatchBookingException implements Exception {
  const MatchBookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
    WeatherService? weather,
    LocationSource? location,
    StadiumDirectory? stadiumDirectory,
  }) : _openStore = openStore ?? _openDefaultStore,
       weather = weather ?? WeatherService(),
       _location = location ?? const GeolocatorLocationSource(),
       _directory = stadiumDirectory ?? HttpStadiumDirectory();

  /// The signed-in player. Local ids are strings so Firebase uids fit later.
  final String uid;
  final String username;
  final MatchStoreOpener _openStore;

  /// Forecast for the match card. Needs a connection; shows nothing offline.
  final WeatherService weather;

  // Placeholders the Match home screen already showed. Real values must come
  // from the API once XP is wired.
  static const level = 1;
  static const streak = 1;
  static const energy = 50;

  final StadiumDirectory _directory;

  /// Stadiums to pick from. Real ones from the Stadium module after
  /// [loadStadiums]; the sample list when the server cannot be reached.
  List<MatchStadiumData> stadiums = matchStadiums;
  bool usingSampleStadiums = true;
  bool stadiumsLoading = false;

  /// Asks the Stadium module for its open stadiums. Falls back to the sample
  /// list, with [usingSampleStadiums] true, for guests, when the server is
  /// unreachable, or when no stadium is open yet.
  Future<void> loadStadiums() async {
    if (stadiumsLoading) return;
    stadiumsLoading = true;
    notifyListeners();
    try {
      final real = await _directory.stadiums();
      if (real.isNotEmpty) {
        stadiums = [
          for (final stadium in real)
            MatchStadiumData(
              stadiumId: stadium.id,
              name: stadium.name,
              distance: stadium.address.split(',').first.trim(),
              coins: stadium.pricePerHour,
              players: stadium.maxCapacity,
            ),
        ];
        usingSampleStadiums = false;
      } else {
        stadiums = matchStadiums;
        usingSampleStadiums = true;
      }
    } on StadiumDirectoryException {
      stadiums = matchStadiums;
      usingSampleStadiums = true;
    } catch (_) {
      stadiums = matchStadiums;
      usingSampleStadiums = true;
    }
    stadiumsLoading = false;
    notifyListeners();
  }

  /// Free slots of a real stadium on [day]. Throws
  /// [StadiumDirectoryException] with a message ready to show.
  Future<List<FreeSlot>> freeSlots(MatchStadiumData stadium, DateTime day) {
    final id = stadium.stadiumId;
    if (id == null) return Future.value(const []);
    return _directory.freeSlots(id, day);
  }

  final LocationSource _location;
  PlayerLocation? _here;

  /// Result of the last "use my location" tap, or null before the first one.
  LocationStatus? locationStatus;
  bool locating = false;

  /// True when the public list is sorted by distance from the player.
  bool get sortedByDistance => _here != null;

  MatchLocalStore? _store;
  Future<void>? _loading;
  Map<String, LocalMatch> _byCode = const {};
  MatchHomeMatch? upcomingMatch;

  /// Matches the player is in, and how many they created. Null until loaded.
  ({int played, int hosted})? stats;

  /// The upcoming matches the player is in, shaped for the calendar.
  List<FootballMatch> get calendarMatches => [
    for (final match in _byCode.values.where((m) => m.hasPlayer(uid)))
      FootballMatch(
        id: match.code,
        scheduledAt: match.scheduledAt,
        stadium: match.stadium,
        joinedSlots: match.players,
        totalSlots: match.capacity,
        isPublic: match.isPublic,
        participation: match.hostUid == uid
            ? MatchParticipation.created
            : MatchParticipation.joined,
      ),
  ];

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
      stats = await store.statsFor(uid);
    } catch (_) {
      lastError = 'Matches could not be loaded from this phone.';
    }
  }

  /// Asks for the phone's location once. The position stays in memory and is
  /// never saved. Afterwards [publicMatches] lists the nearest matches first.
  Future<void> useMyLocation() async {
    if (locating) return;
    locating = true;
    notifyListeners();
    final result = await _location.current();
    locating = false;
    locationStatus = result.status;
    _here = result.status == LocationStatus.granted ? result.location : null;
    notifyListeners();
  }

  /// Public matches. With the player's location on, matches with free places
  /// come first, nearest first; otherwise soonest first.
  List<MatchPublicListing> get publicMatches {
    final here = _here;
    final listings = [
      for (final match in _byCode.values.where((match) => match.isPublic))
        (
          match: match,
          distance: here != null && match.hasLocation
              ? distanceKm(
                  here.latitude,
                  here.longitude,
                  match.latitude!,
                  match.longitude!,
                )
              : null,
        ),
    ];
    if (here != null) {
      listings.sort((a, b) {
        if (a.match.isFull != b.match.isFull) return a.match.isFull ? 1 : -1;
        final da = a.distance, db = b.distance;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }
    return [
      for (final item in listings)
        MatchPublicListing(
          match: _toHome(item.match),
          timeLabel: _publicTime(item.match.scheduledAt.toLocal()),
          isToday: DateUtils.isSameDay(
            item.match.scheduledAt.toLocal(),
            DateTime.now(),
          ),
          distanceKm: item.distance,
        ),
    ];
  }

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

  /// Saves a new match with the player as host. In a real stadium it also
  /// holds the picked slot; if that fails the match is removed again and
  /// [MatchBookingException] is thrown. Throws [LocalMatchException] when the
  /// input is not valid.
  Future<MatchHomeMatch> createMatch(CreateMatchDraft draft) async {
    final store = await _ensureStore();
    var created = await store.create(
      hostUid: uid,
      hostName: username,
      stadium: draft.stadium.name,
      scheduledAt: draft.startsAt,
      capacity: draft.capacity,
      isPublic: draft.visibility == 'Public',
      latitude: draft.stadium.latitude,
      longitude: draft.stadium.longitude,
    );
    final slot = draft.slot;
    final stadiumId = draft.stadium.stadiumId;
    if (slot != null && stadiumId != null) {
      final int bookingId;
      try {
        bookingId = await _directory.hold(
          stadiumId: stadiumId,
          pitchId: slot.pitch.id,
          day: DateUtils.dateOnly(draft.startsAt),
          start: slot.start,
          matchCode: created.code,
        );
      } on StadiumDirectoryException catch (error) {
        await store.cancel(created.code, uid);
        await _refresh();
        notifyListeners();
        throw MatchBookingException(error.message);
      }
      created = await store.setBookingId(created.code, uid, bookingId);
    }
    await _refresh(focusCode: created.code);
    notifyListeners();
    return _toHome(created);
  }

  /// True when the player created this match.
  bool isHost(MatchHomeMatch match) =>
      _byCode[match.code.toUpperCase()]?.hostUid == uid;

  /// Frees the player's place. The host cancels instead.
  Future<bool> leaveMatch(String code) async =>
      _change(() async => (await _ensureStore()).leave(code, uid));

  /// Removes the match and everyone in it. Only the host can do this. A
  /// stadium slot held for the match is released first; if that fails the
  /// match stays so the host can try again.
  Future<bool> cancelMatch(String code) async {
    final known = _byCode[code.trim().toUpperCase()];
    if (known != null && known.players > maxPlayersToCancel) {
      lastError =
          'This match has more than $maxPlayersToCancel players, so it '
          'cannot be cancelled. Ask players to leave first.';
      notifyListeners();
      return false;
    }
    final bookingId = known?.bookingId;
    if (bookingId != null) {
      try {
        await _directory.release(bookingId);
      } on Object {
        // The slot could not be freed (offline, 404...). The host must still
        // be able to cancel; the stadium frees the slot on its side later.
      }
    }
    return _change(() async => (await _ensureStore()).cancel(code, uid));
  }

  /// Adds sample public matches by other players, for trying the app out.
  Future<int> loadDemoMatches() async {
    final added = await seedDemoMatches(await _ensureStore());
    await _refresh();
    notifyListeners();
    return added;
  }

  /// Makes the match public or private. Only the host can.
  Future<bool> setPublic(String code, {required bool isPublic}) => _change(
    () async =>
        (await _ensureStore()).setPublic(code, uid, isPublic: isPublic),
  );

  Future<bool> _change(Future<Object?> Function() action) async {
    lastError = null;
    try {
      await action();
      await _refresh();
      notifyListeners();
      return true;
    } on LocalMatchException catch (error) {
      lastError = error.message;
      return false;
    }
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
