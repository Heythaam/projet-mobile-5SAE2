// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../bd/doc_store.dart';
import 'stadium_directory.dart';
import '../tournament/tournament_store.dart';
import '../../views/stadium/stadium_module.dart';
import 'stadium_rules.dart';
import 'stadium_store.dart';

typedef StadiumCache = Future<DocStore> Function();

/// Reads stadiums from the cloud and keeps a copy on the phone in SQFlite, so
/// the lists still open without a connection. Changes need a connection.
class StadiumRepo {
  StadiumRepo({required this.store, this.cache});

  final StadiumStore store;
  final StadiumCache? cache;

  static const collection = 'stadiums';

  Future<List<Doc>> all() async {
    try {
      final docs = await store.all();
      await _save(docs);
      return docs;
    } catch (error) {
      final cached = await _cached();
      if (cached.isEmpty) rethrow;
      debugPrint('Stadiums read from the phone copy: $error');
      return cached;
    }
  }

  Future<void> _save(List<Doc> docs) async {
    final open = cache;
    if (open == null) return;
    try {
      await (await open()).replaceAll(collection, {
        for (final doc in docs) '${doc['id']}': doc,
      });
    } catch (_) {}
  }

  Future<List<Doc>> _cached() async {
    final open = cache;
    if (open == null) return const [];
    try {
      return [
        for (final json in await (await open()).list(collection))
          cloneDoc(json),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// The owner screens of the Stadium module on Firestore.
class FirestoreStadiumApi implements StadiumApi {
  FirestoreStadiumApi({
    required this.meId,
    required this.meName,
    required StadiumRepo repo,
  }) : _repo = repo;

  final int meId;
  final String meName;
  final StadiumRepo _repo;

  StadiumStore get _store => _repo.store;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(const Duration(seconds: 20));
    } on StadiumFailure catch (error) {
      throw StadiumApiException(error.message);
    } on TournamentMissing {
      throw const StadiumApiException('Stadium not found.');
    } on TimeoutException {
      throw const StadiumApiException('The server took too long to answer.');
    } catch (error) {
      debugPrint('Stadium request failed: $error');
      throw const StadiumApiException(
        "Can't reach the cloud. Check your internet connection.",
      );
    }
  }

  Future<List<Doc>> _owned() async => [
    for (final doc in await _repo.all())
      if (doc['ownerId'] == meId) doc,
  ];

  Future<Doc> _ownedDoc(int id) async {
    final doc = await _store.get(id);
    if (doc == null) throw const StadiumFailure(404, 'Stadium not found.');
    StadiumRules.requireOwner(doc, meId);
    return doc;
  }

  Stadium _stadium(Doc doc) =>
      Stadium.fromJson(StadiumRules.stadiumJson(doc).cast<String, dynamic>());

  @override
  Future<StadiumOverview> overview() => _run(
    () async => StadiumOverview.fromJson(
      StadiumRules.overview(await _owned()).cast<String, dynamic>(),
    ),
  );

  @override
  Future<Stadium> stadium(int id) => _run(() async => _stadium(await _ownedDoc(id)));

  @override
  Future<Stadium> create(StadiumDraft draft) => _run(() async {
    final input = StadiumRules.parse(draft.toJson().cast<String, dynamic>());
    final doc = await _store.create(
      (id) => StadiumRules.create(id, meId, input),
    );
    return _stadium(doc);
  });

  @override
  Future<Stadium> update(int id, StadiumDraft draft) => _run(() async {
    final input = StadiumRules.parse(draft.toJson().cast<String, dynamic>());
    final doc = await _store.mutate(
      id,
      (doc) => StadiumRules.update(doc, meId, input),
    );
    return _stadium(doc);
  });

  @override
  Future<void> delete(int id) => _run(() async {
    StadiumRules.requireDeletable(await _ownedDoc(id), meId);
    await _store.delete(id);
  });

  @override
  Future<Stadium> setPaused(int id, bool paused) => _run(() async {
    final doc = await _store.mutate(
      id,
      (doc) => StadiumRules.pause(doc, meId, paused),
    );
    return _stadium(doc);
  });

  @override
  Future<DayAvailability> availability(int id, DateTime day) =>
      _run(() async {
        final doc = await _ownedDoc(id);
        return DayAvailability.fromJson(
          StadiumRules.availability(
            doc,
            stadiumDay(day),
            forOwner: true,
          ).cast<String, dynamic>(),
        );
      });

  @override
  Future<void> block(int stadiumId, int pitchId, DateTime day, int start) =>
      _run(() async {
        await _store.mutate(
          stadiumId,
          (doc) =>
              StadiumRules.block(doc, meId, pitchId, stadiumDay(day), start),
        );
      });

  @override
  Future<void> unblock(int blockId) => _run(() async {
    await _store.mutate(
      stadiumOfId(blockId),
      (doc) => StadiumRules.unblock(doc, meId, blockId),
    );
  });

  @override
  Future<BookingInbox> inbox() => _run(() async {
    final owned = await _owned();
    final auto = await _store.autoConfirm(meId);
    return BookingInbox.fromJson(
      StadiumRules.inbox(owned, auto).cast<String, dynamic>(),
    );
  });

  @override
  Future<void> decide(int bookingId, {required bool accept}) => _run(() async {
    await _store.mutate(
      stadiumOfId(bookingId),
      (doc) => StadiumRules.decide(doc, meId, bookingId, accept: accept),
    );
  });

  @override
  Future<void> setAutoConfirm(bool value) =>
      _run(() => _store.setAutoConfirm(meId, value));
}

/// What the Match module uses to find stadiums and hold a slot, on Firestore.
class FirestoreStadiumDirectory
    implements StadiumDirectory, StadiumReviewSource {
  FirestoreStadiumDirectory({
    required this.meId,
    required this.meName,
    required StadiumRepo repo,
  }) : _repo = repo;

  final int meId;
  final String meName;
  final StadiumRepo _repo;

  StadiumStore get _store => _repo.store;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(const Duration(seconds: 20));
    } on StadiumFailure catch (error) {
      throw StadiumDirectoryException(error.message, statusCode: error.status);
    } on TournamentMissing {
      throw const StadiumDirectoryException(
        'Stadium not found.',
        statusCode: 404,
      );
    } on TimeoutException {
      throw const StadiumDirectoryException(
        'The server took too long to answer.',
      );
    } catch (error) {
      debugPrint('Stadium directory request failed: $error');
      throw const StadiumDirectoryException(
        "Can't reach the cloud. Check your internet connection.",
      );
    }
  }

  @override
  Future<List<RealStadium>> stadiums() => _run(() async {
    final open = [
      for (final doc in await _repo.all())
        if (doc['paused'] != true) doc,
    ]..sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      );
    return [
      for (final doc in open)
        RealStadium.fromJson(StadiumRules.stadiumJson(doc).cast<String, dynamic>()),
    ];
  });

  @override
  Future<List<FreeSlot>> freeSlots(int stadiumId, DateTime day) =>
      _run(() async {
        final doc = await _store.get(stadiumId);
        if (doc == null || doc['paused'] == true) {
          throw const StadiumFailure(404, 'Stadium not found.');
        }
        final json = StadiumRules.availability(
          doc,
          stadiumDay(day),
          forOwner: false,
        );
        if (json['open'] == false) return const <FreeSlot>[];
        final slots = <FreeSlot>[];
        for (final item in json['pitches']! as List<Object?>) {
          final map = item! as Map<String, Object?>;
          final pitch = RealPitch(
            id: map['id']! as int,
            name: map['name'] as String? ?? '',
            size: map['size'] as String? ?? '5v5',
          );
          for (final raw in map['slots']! as List<Object?>) {
            final slot = raw! as Map<String, Object?>;
            if (slot['state'] != 'free') continue;
            slots.add(
              FreeSlot(
                pitch: pitch,
                start: slot['start']! as int,
                end: slot['end']! as int,
                price: slot['price']! as int,
              ),
            );
          }
        }
        slots.sort((a, b) {
          final byTime = a.start.compareTo(b.start);
          return byTime != 0 ? byTime : a.pitch.name.compareTo(b.pitch.name);
        });
        return slots;
      });

  @override
  Future<int> hold({
    required int stadiumId,
    required int pitchId,
    required DateTime day,
    required int start,
    required String matchCode,
  }) => _run(() async {
    final known = await _store.get(stadiumId);
    if (known == null) throw const StadiumFailure(404, 'Stadium not found.');
    final auto = await _store.autoConfirm(known['ownerId'] as int);
    late Doc booking;
    await _store.mutate(
      stadiumId,
      (doc) => booking = StadiumRules.hold(
        doc,
        hostId: meId,
        hostName: meName,
        pitchId: pitchId,
        day: stadiumDay(day),
        start: start,
        matchId: matchCode,
        autoConfirm: auto,
      ),
    );
    return booking['id']! as int;
  });

  @override
  Future<void> release(int bookingId) => _run(() async {
    await _store.mutate(
      stadiumOfId(bookingId),
      (doc) => StadiumRules.release(doc, meId, bookingId),
    );
  });

  @override
  Future<StadiumReviewSet> reviews(int stadiumId) => _run(() async {
    final doc = await _store.get(stadiumId);
    if (doc == null) throw const StadiumFailure(404, 'Stadium not found.');
    return StadiumReviewSet.fromJson(
      StadiumRules.reviewsJson(doc, meId).cast<String, dynamic>(),
    );
  });

  @override
  Future<void> submitReview(
    int stadiumId, {
    required int stars,
    required String comment,
  }) => _run(() async {
    await _store.mutate(
      stadiumId,
      (doc) => StadiumRules.addReview(
        doc,
        userId: meId,
        userName: meName,
        stars: stars,
        comment: comment,
      ),
    );
  });
}
