import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/stadium/stadium_directory.dart';
import 'package:football_match_app/services/stadium/firestore_stadiums.dart';
import 'package:football_match_app/views/stadium/stadium_module.dart';
import 'package:football_match_app/services/stadium/stadium_store.dart';

/// A day at least two days ahead that is not a Sunday (the default draft is
/// open Monday to Saturday).
DateTime _openDay() {
  var day = DateTime.now().add(const Duration(days: 2));
  while (day.weekday == DateTime.sunday) {
    day = day.add(const Duration(days: 1));
  }
  return DateTime(day.year, day.month, day.day);
}

void main() {
  late InMemoryStadiumStore store;
  late StadiumRepo repo;
  late FirestoreStadiumApi owner;
  late FirestoreStadiumApi stranger;
  late FirestoreStadiumDirectory player;
  late FirestoreStadiumDirectory otherPlayer;

  setUp(() {
    store = InMemoryStadiumStore();
    repo = StadiumRepo(store: store);
    owner = FirestoreStadiumApi(meId: 1, meName: 'owner', repo: repo);
    stranger = FirestoreStadiumApi(meId: 9, meName: 'stranger', repo: repo);
    player = FirestoreStadiumDirectory(meId: 2, meName: 'ana', repo: repo);
    otherPlayer = FirestoreStadiumDirectory(meId: 3, meName: 'ben', repo: repo);
  });

  Future<Stadium> makeStadium() => owner.create(
    StadiumDraft(name: 'Camp Nou', phone: '+216 20 000 000', address: 'Tunis'),
  );

  test('an owner adds a stadium and players see it', () async {
    final stadium = await makeStadium();
    expect(stadium.pitches.single.name, 'A');

    final overview = await owner.overview();
    expect(overview.stadiums.single.stadium.name, 'Camp Nou');

    final listed = await player.stadiums();
    expect(listed.single.name, 'Camp Nou');
    expect((await stranger.overview()).stadiums, isEmpty);
    await expectLater(
      stranger.stadium(stadium.id),
      throwsA(isA<StadiumApiException>()),
    );
  });

  test('a stadium form with a bad phone is refused', () async {
    await expectLater(
      owner.create(StadiumDraft(name: 'Camp Nou', phone: 'abc', address: 'Tunis')),
      throwsA(isA<StadiumApiException>()),
    );
  });

  test('a held slot waits for the owner, who accepts it', () async {
    final stadium = await makeStadium();
    final day = _openDay();
    final pitchId = stadium.pitches.single.id!;

    final before = await player.freeSlots(stadium.id, day);
    expect(before.any((slot) => slot.start == 17 * 60), isTrue);

    final bookingId = await player.hold(
      stadiumId: stadium.id,
      pitchId: pitchId,
      day: day,
      start: 17 * 60,
      matchCode: 'ABC123',
    );

    final after = await otherPlayer.freeSlots(stadium.id, day);
    expect(after.any((slot) => slot.start == 17 * 60), isFalse);
    await expectLater(
      otherPlayer.hold(
        stadiumId: stadium.id,
        pitchId: pitchId,
        day: day,
        start: 17 * 60,
        matchCode: 'ZZZ999',
      ),
      throwsA(
        isA<StadiumDirectoryException>().having(
          (e) => e.statusCode,
          'status',
          409,
        ),
      ),
    );

    var inbox = await owner.inbox();
    expect(inbox.pending.single.hostName, 'ana');
    expect((await owner.overview()).pendingBookings, 1);

    await owner.decide(bookingId, accept: true);
    inbox = await owner.inbox();
    expect(inbox.pending, isEmpty);
    expect(inbox.confirmed.single.id, bookingId);

    await expectLater(
      owner.decide(bookingId, accept: true),
      throwsA(isA<StadiumApiException>()),
    );
  });

  test('auto confirm confirms bookings at once', () async {
    final stadium = await makeStadium();
    await owner.setAutoConfirm(true);
    await player.hold(
      stadiumId: stadium.id,
      pitchId: stadium.pitches.single.id!,
      day: _openDay(),
      start: 18 * 60,
      matchCode: 'ABC123',
    );
    final inbox = await owner.inbox();
    expect(inbox.autoConfirm, isTrue);
    expect(inbox.confirmed, hasLength(1));
  });

  test('releasing a booking frees the slot', () async {
    final stadium = await makeStadium();
    final day = _openDay();
    final bookingId = await player.hold(
      stadiumId: stadium.id,
      pitchId: stadium.pitches.single.id!,
      day: day,
      start: 17 * 60,
      matchCode: 'ABC123',
    );
    await expectLater(
      otherPlayer.release(bookingId),
      throwsA(isA<StadiumDirectoryException>()),
    );
    await player.release(bookingId);
    final free = await otherPlayer.freeSlots(stadium.id, day);
    expect(free.any((slot) => slot.start == 17 * 60), isTrue);
  });

  test('blocking hides a slot and booked slots cannot be blocked', () async {
    final stadium = await makeStadium();
    final day = _openDay();
    final pitchId = stadium.pitches.single.id!;

    await owner.block(stadium.id, pitchId, day, 19 * 60);
    var free = await player.freeSlots(stadium.id, day);
    expect(free.any((slot) => slot.start == 19 * 60), isFalse);

    final availability = await owner.availability(stadium.id, day);
    final slot = availability.pitches.single.slots.firstWhere(
      (s) => s.start == 19 * 60,
    );
    expect(slot.state, SlotState.blocked);
    await owner.unblock(slot.blockId!);
    free = await player.freeSlots(stadium.id, day);
    expect(free.any((s) => s.start == 19 * 60), isTrue);

    await player.hold(
      stadiumId: stadium.id,
      pitchId: pitchId,
      day: day,
      start: 17 * 60,
      matchCode: 'ABC123',
    );
    await expectLater(
      owner.block(stadium.id, pitchId, day, 17 * 60),
      throwsA(isA<StadiumApiException>()),
    );
  });

  test('a stadium with bookings cannot be deleted but can be paused', () async {
    final stadium = await makeStadium();
    await player.hold(
      stadiumId: stadium.id,
      pitchId: stadium.pitches.single.id!,
      day: _openDay(),
      start: 17 * 60,
      matchCode: 'ABC123',
    );
    await expectLater(
      owner.delete(stadium.id),
      throwsA(isA<StadiumApiException>()),
    );
    final paused = await owner.setPaused(stadium.id, true);
    expect(paused.paused, isTrue);
    expect(await player.stadiums(), isEmpty);
  });

  test('an empty stadium can be deleted', () async {
    final stadium = await makeStadium();
    await owner.delete(stadium.id);
    expect((await owner.overview()).stadiums, isEmpty);
  });

  test('only players who booked can review, once each', () async {
    final stadium = await makeStadium();
    await expectLater(
      otherPlayer.submitReview(stadium.id, stars: 5, comment: 'Great'),
      throwsA(isA<StadiumDirectoryException>()),
    );
    expect((await otherPlayer.reviews(stadium.id)).canReview, isFalse);

    await player.hold(
      stadiumId: stadium.id,
      pitchId: stadium.pitches.single.id!,
      day: _openDay(),
      start: 17 * 60,
      matchCode: 'ABC123',
    );
    expect((await player.reviews(stadium.id)).canReview, isTrue);
    await expectLater(
      player.submitReview(stadium.id, stars: 6, comment: ''),
      throwsA(isA<StadiumDirectoryException>()),
    );
    await player.submitReview(stadium.id, stars: 4, comment: 'Nice pitch');
    await player.submitReview(stadium.id, stars: 5, comment: 'Even better');

    final set = await otherPlayer.reviews(stadium.id);
    expect(set.count, 1);
    expect(set.rating, 5.0);
    expect(set.reviews.single.userName, 'ana');
    expect(set.reviews.single.mine, isFalse);
    expect((await player.reviews(stadium.id)).reviews.single.mine, isTrue);

    final listed = await otherPlayer.stadiums();
    expect(listed.single.rating, 5.0);
    expect(listed.single.reviewCount, 1);
  });
}
