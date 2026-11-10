import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/tournaments/cloud/firestore_tournament_service.dart';
import 'package:football_match_app/tournaments/cloud/tournament_store.dart';
import 'package:football_match_app/tournaments/models/tournament.dart';
import 'package:football_match_app/tournaments/services/tournament_service.dart';

FirestoreTournamentService _as(
  InMemoryTournamentStore store,
  int id,
  String name,
) => FirestoreTournamentService(meId: id, meName: name, store: store);

Future<Tournament> _create(
  FirestoreTournamentService service, {
  int maxTeams = 4,
  int teamSize = 3,
}) => service.createTournament(
  name: 'Spring Cup',
  format: 'knockout',
  startDate: '2026-12-01',
  endDate: '2026-12-10',
  maxTeams: maxTeams,
  teamSize: teamSize,
);

Matcher _fails(int status, [String? code]) => throwsA(
  isA<TournamentException>()
      .having((e) => e.statusCode, 'status', status)
      .having((e) => e.code, 'code', code),
);

void main() {
  late InMemoryTournamentStore store;
  late FirestoreTournamentService organizer;
  late FirestoreTournamentService ana;
  late FirestoreTournamentService ben;
  late FirestoreTournamentService cleo;

  setUp(() {
    store = InMemoryTournamentStore();
    organizer = _as(store, 1, 'org');
    ana = _as(store, 2, 'ana');
    ben = _as(store, 3, 'ben');
    cleo = _as(store, 4, 'cleo');
  });

  test('a tournament made on one phone is listed on another', () async {
    final made = await _create(organizer);
    expect(made.isOrganizer, isTrue);
    expect(made.status, TournamentStatus.upcoming);

    final seen = await ana.getTournaments();
    expect(seen.tournaments.map((t) => t.id), [made.id]);
    expect(seen.tournaments.first.isOrganizer, isFalse);
    expect(seen.tournaments.first.createdBy, 'org');
  });

  test('create validates the form', () async {
    expect(
      organizer.createTournament(
        name: 'x',
        format: 'knockout',
        startDate: '2026-12-01',
        endDate: '2026-12-10',
        maxTeams: 4,
        teamSize: 3,
      ),
      _fails(400),
    );
    expect(
      organizer.createTournament(
        name: 'Valid name',
        format: 'knockout',
        startDate: '2026-12-10',
        endDate: '2026-12-01',
        maxTeams: 4,
        teamSize: 3,
      ),
      _fails(400),
    );
  });

  test('joining creates a team, once, with a free name', () async {
    final t = await _create(organizer, maxTeams: 2);
    final joined = await ana.joinTournament(t.id, 'Red   Lions');
    expect(joined.joined, isTrue);
    expect(joined.currentTeams, 1);
    expect(joined.teams.single.name, 'Red Lions');

    expect(ana.joinTournament(t.id, 'Other'), _fails(409));
    expect(ben.joinTournament(t.id, 'red lions'), _fails(409));
    await ben.joinTournament(t.id, 'Blue Sharks');
    expect(cleo.joinTournament(t.id, 'Third'), _fails(409));
  });

  test('the organizer is told when a team joins', () async {
    final t = await _create(organizer);
    await ana.joinTournament(t.id, 'Red Lions');
    final notes = await organizer.getNotifications();
    expect(notes.single.title, 'New Team Joined');
    expect(notes.single.isRead, isFalse);
    await organizer.markNotificationRead(notes.single.id);
    expect((await organizer.getNotifications()).single.isRead, isTrue);
  });

  test('a player asks, the captain accepts, the team grows', () async {
    final t = await _create(organizer, teamSize: 2);
    final withTeam = await ana.joinTournament(t.id, 'Red Lions');
    final teamId = withTeam.myTeamId!;

    final asked = await ben.requestToJoinTeam(t.id, teamId);
    expect(asked.hasPendingRequest, isTrue);
    expect(ben.requestToJoinTeam(t.id, teamId), _fails(409));

    expect(await ana.getPendingRequestCount(), 1);
    final requests = await ana.getJoinRequests(t.id);
    expect(requests.single.requesterName, 'ben');

    await ana.answerJoinRequest(t.id, requests.single.id, accept: true);
    final benView = await ben.getTournament(t.id);
    expect(benView.myTeamId, teamId);
    expect(benView.isTeamPlayer, isTrue);
    expect(benView.canLeave, isTrue);
    expect(await ana.getPendingRequestCount(), 0);

    // The team is full now.
    expect(cleo.requestToJoinTeam(t.id, teamId), _fails(409));
    final notes = await ben.getNotifications();
    expect(notes.single.title, 'Join Request Accepted');
  });

  test('a declined player cannot ask the same team again', () async {
    final t = await _create(organizer);
    final teamId = (await ana.joinTournament(t.id, 'Red Lions')).myTeamId!;
    await ben.requestToJoinTeam(t.id, teamId);
    final request = (await ana.getJoinRequests(t.id)).single;
    await ana.answerJoinRequest(t.id, request.id, accept: false);
    expect(ben.requestToJoinTeam(t.id, teamId), _fails(409));
  });

  test('a captain with players must transfer or disband', () async {
    final t = await _create(organizer);
    final teamId = (await ana.joinTournament(t.id, 'Red Lions')).myTeamId!;
    await ben.requestToJoinTeam(t.id, teamId);
    final request = (await ana.getJoinRequests(t.id)).single;
    await ana.answerJoinRequest(t.id, request.id, accept: true);

    final view = await ana.getTournament(t.id);
    expect(view.canLeave, isFalse);
    expect(view.canTransfer, isTrue);
    expect(view.canDisband, isTrue);
    expect(ana.leaveTournament(t.id), _fails(409));

    final moved = await ana.transferCaptaincy(t.id, 3);
    expect(moved.joined, isFalse);
    expect(moved.isTeamPlayer, isTrue);
    expect((await ben.getTournament(t.id)).joined, isTrue);
    expect(
      ana.transferCaptaincy(t.id, 3),
      _fails(403, 'not_captain'),
    );
  });

  test('disbanding frees the players and tells them', () async {
    final t = await _create(organizer);
    final teamId = (await ana.joinTournament(t.id, 'Red Lions')).myTeamId!;
    await ben.requestToJoinTeam(t.id, teamId);
    final request = (await ana.getJoinRequests(t.id)).single;
    await ana.answerJoinRequest(t.id, request.id, accept: true);

    final after = await ana.disbandTeam(t.id);
    expect(after.joined, isFalse);
    expect(after.currentTeams, 0);

    final benView = await ben.getTournament(t.id);
    expect(benView.hasTeam, isFalse);
    expect(benView.teamDisbanded, isTrue);
    await ben.dismissDisbandNotice(t.id);
    expect((await ben.getTournament(t.id)).teamDisbanded, isFalse);
  });

  test('the captain removes a player, who is told and blocked', () async {
    final t = await _create(organizer);
    final teamId = (await ana.joinTournament(t.id, 'Red Lions')).myTeamId!;
    await ben.requestToJoinTeam(t.id, teamId);
    final request = (await ana.getJoinRequests(t.id)).single;
    await ana.answerJoinRequest(t.id, request.id, accept: true);

    final team = await ana.removePlayer(t.id, teamId, 3);
    expect(team.players.length, 1);
    final benView = await ben.getTournament(t.id);
    expect(benView.removedFromTeam, isTrue);
    expect(ben.requestToJoinTeam(t.id, teamId), _fails(409));
  });

  test('only the organizer starts it, and it needs two teams', () async {
    final t = await _create(organizer);
    await ana.joinTournament(t.id, 'Red Lions');
    expect(ana.updateTournamentStatus(t.id, 'active'), _fails(403));
    expect(organizer.updateTournamentStatus(t.id, 'active'), _fails(409));

    await ben.joinTournament(t.id, 'Blue Sharks');
    final started = await organizer.updateTournamentStatus(t.id, 'active');
    expect(started.status, TournamentStatus.active);

    // Registration is closed and details are locked.
    expect(cleo.joinTournament(t.id, 'Late'), _fails(409));
    expect(organizer.editTournament(t.id, name: 'Renamed'), _fails(409));
  });

  test('with no connection and no phone copy the list reports an error', () {
    store.offline = true;
    expect(ana.getTournaments(), throwsA(isA<TournamentException>()));
  });
}
