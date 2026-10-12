import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/api_client.dart';
import 'package:football_match_app/tournaments/models/player_profile.dart';
import 'package:football_match_app/tournaments/models/tournament.dart';
import 'package:football_match_app/tournaments/screens/tournament_detail_screen.dart';
import 'package:football_match_app/tournaments/screens/tournament_standings_screen.dart';
import 'package:football_match_app/tournaments/screens/tournaments_list_screen.dart';
import 'package:football_match_app/tournaments/services/tournament_service.dart';
import 'package:football_match_app/tournaments/tournament_constants.dart';
import 'package:football_match_app/app_route_observer.dart';
import 'package:football_match_app/tournaments/widgets/bracket_widget.dart';
import 'package:football_match_app/tournaments/widgets/sheet_frame.dart';
import 'package:football_match_app/tournaments/widgets/tournament_states.dart';

void main() {
  group('TeamName', () {
    test('normalizes spaces like the API', () {
      expect(TeamName.normalize('  Red   Lions '), 'Red Lions');
    });

    test('accepts letters, numbers and simple punctuation', () {
      for (final name in ['Red Lions', "Bob's F.C. 2-0_", 'Équipe Sfax']) {
        expect(TeamName.validate(name), isNull, reason: name);
      }
    });

    test('rejects short, long and symbol-only names', () {
      expect(TeamName.validate('  ab  '), TournamentStrings.TEAM_NAME_LENGTH);
      expect(TeamName.validate('x' * 31), TournamentStrings.TEAM_NAME_LENGTH);
      expect(
        TeamName.validate('<b>Lions</b>'),
        TournamentStrings.TEAM_NAME_CHARACTERS,
      );
      expect(TeamName.validate('---'), TournamentStrings.TEAM_NAME_CHARACTERS);
    });
  });

  group('TournamentService', () {
    test('parses the list and forwards the status filter', () async {
      final api = _FakeApi({
        'GET /tournaments?status=upcoming': {
          'tournaments': [_tournamentJson()],
        },
      });
      final tournaments = await TournamentService(api)
          .getTournaments(status: TournamentStatus.upcoming);

      expect(api.calls, ['GET /tournaments?status=upcoming']);
      expect(tournaments.single.name, 'Sunday Cup');
      expect(tournaments.single.format, TournamentFormat.league);
      expect(tournaments.single.spotsLeft, 12);
      expect(tournaments.single.canJoin, isTrue);
    });

    test('wraps API errors and keeps the status code', () async {
      final api = _FakeApi({
        'POST /tournaments/7/join': const ApiException(
          'Tournament is full.',
          statusCode: 409,
        ),
      });

      await expectLater(
        TournamentService(api).joinTournament(7, 'Red Lions'),
        throwsA(
          isA<TournamentException>()
              .having(
                (error) => error.message,
                'message',
                'Tournament is full.',
              )
              .having((error) => error.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('sends the normalized team name when joining', () async {
      final api = _FakeApi({
        'POST /tournaments/7/join': {
          'tournament': _tournamentJson(joined: true),
        },
      });

      await TournamentService(api).joinTournament(7, '  Red   Lions ');

      expect(api.bodies['POST /tournaments/7/join'], {'name': 'Red Lions'});
    });

    test('leaves with DELETE on the join path', () async {
      final api = _FakeApi({
        'DELETE /tournaments/7/join': {'tournament': _tournamentJson()},
      });

      final tournament = await TournamentService(api).leaveTournament(7);

      expect(api.calls, ['DELETE /tournaments/7/join']);
      expect(tournament.joined, isFalse);
    });

    test('sends, lists and answers join requests', () async {
      final api = _FakeApi({
        'POST /tournaments/7/teams/1/request': {
          'tournament': _tournamentJson(
            myRequests: [
              {'teamId': 1, 'status': 'pending'},
            ],
          ),
        },
        'GET /tournaments/7/requests': {
          'requests': [_requestJson()],
        },
        'PUT /tournaments/7/requests/31': {
          'request': {..._requestJson(), 'status': 'declined'},
        },
      });
      final service = TournamentService(api);

      final tournament = await service.requestToJoinTeam(7, 1);
      expect(tournament.requestFor(1)?.status, JoinRequestStatus.pending);
      final requests = await service.getJoinRequests(7);
      expect(requests.single.requesterName, 'erling');
      expect(requests.single.createdAt.isUtc, isTrue);
      final answered = await service.answerJoinRequest(7, 31, accept: false);

      expect(answered.status, JoinRequestStatus.declined);
      expect(api.bodies['PUT /tournaments/7/requests/31'], {
        'status': 'declined',
      });
    });

    test('reads request times with or without a zone marker', () {
      for (final createdAt in [
        '2026-10-11 15:35:09',
        '2026-10-11T15:35:09Z',
        '2026-10-11T16:35:09+01:00',
      ]) {
        final request = TeamJoinRequest.fromJson({
          ..._requestJson(),
          'createdAt': createdAt,
        });
        expect(
          request.createdAt.toUtc(),
          DateTime.utc(2026, 10, 11, 15, 35, 9),
          reason: createdAt,
        );
      }
    });

    test(
      'loads teams, profiles and the pending total; removes players',
      () async {
        final api = _FakeApi({
          'GET /me/tournament-requests': {'pendingRequests': 3},
          'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
          'DELETE /tournaments/7/teams/1/members/11': {
            'team': _teamDetailsJson(
              players: [
                _playerJson(id: 10, username: 'captain_kai', isCaptain: true),
              ],
            ),
          },
          'GET /users/131/profile': {'profile': _profileJson()},
        });
        final service = TournamentService(api);

        expect(await service.getPendingRequestCount(), 3);
        final team = await service.getTeam(7, 1);
        expect(team.players.map((player) => player.username), [
          'captain_kai',
          'erling',
        ]);
        final afterRemove = await service.removePlayer(7, 1, 11);
        expect(afterRemove.players, hasLength(1));
        final profile = await service.getPlayerProfile(131);
        expect(profile.recentMatches.single.result, MatchResult.win);
        expect(profile.achievements.single.title, 'FIRST KICKOFF');
      },
    );

    test('reports malformed responses', () async {
      final api = _FakeApi({
        'GET /tournaments/7/standings': {'standings': 'nope'},
      });

      await expectLater(
        TournamentService(api).getStandings(7),
        throwsA(
          isA<TournamentException>().having(
            (error) => error.message,
            'message',
            TournamentStrings.ERROR_INVALID_RESPONSE,
          ),
        ),
      );
    });

    test('hides raw network errors from players', () async {
      final api = _FakeApi({
        'GET /tournaments': StateError('socket 10.0.2.2:8080 refused'),
      });

      await expectLater(
        TournamentService(api).getTournaments(),
        throwsA(
          isA<TournamentException>().having(
            (error) => error.message,
            'message',
            TournamentStrings.ERROR_LOAD_LIST,
          ),
        ),
      );
    });
  });

  testWidgets('list shows skeleton cards, then tournaments and filters', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [
          _tournamentJson(),
          _tournamentJson(id: 8, name: 'Old Cup', status: 'finished'),
        ],
      },
      'GET /tournaments?status=active': {'tournaments': <Object>[]},
    }, gate: gate);
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('tournament_skeleton')),
      findsNWidgets(TournamentSizes.SKELETON_CARDS),
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sunday Cup'), findsOneWidget);
    expect(find.text('Old Cup'), findsOneWidget);
    expect(find.text('4/16 teams'), findsNWidgets(2));
    expect(find.text(TournamentStrings.JOIN_NOW), findsOneWidget);
    expect(find.text(TournamentStrings.VIEW_DETAILS), findsOneWidget);
    expect(find.text('Nov 1 – Nov 2, 2026 · League'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(TournamentStrings.STATUS_ACTIVE));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.EMPTY_LIST), findsOneWidget);
  });

  testWidgets('a slow earlier filter cannot overwrite the current one', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [_tournamentJson()],
      },
      'GET /tournaments?status=active': {
        'tournaments': [_tournamentJson(id: 9, name: 'Live Cup')],
      },
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pumpAndSettle();

    final slowActive = Completer<void>();
    api.gates['GET /tournaments?status=active'] = slowActive;
    await tester.tap(find.text(TournamentStrings.STATUS_ACTIVE));
    await tester.pump();
    await tester.tap(find.text(TournamentStrings.FILTER_ALL));
    await tester.pumpAndSettle();
    slowActive.complete();
    await tester.pumpAndSettle();

    expect(find.text('Sunday Cup'), findsOneWidget);
    expect(find.text('Live Cup'), findsNothing);
  });

  testWidgets('search narrows the loaded list', (tester) async {
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [
          _tournamentJson(),
          _tournamentJson(id: 8, name: 'Old Cup', status: 'finished'),
        ],
      },
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(TournamentStrings.SEARCH));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'old');
    await tester.pumpAndSettle();
    expect(find.text('Old Cup'), findsOneWidget);
    expect(find.text('Sunday Cup'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.EMPTY_SEARCH), findsOneWidget);
  });

  testWidgets('list shows an error with retry', (tester) async {
    final api = _FakeApi({
      'GET /tournaments': const ApiException('Server unavailable.'),
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server unavailable.'), findsOneWidget);
    api.responses['GET /tournaments'] = {
      'tournaments': [_tournamentJson()],
    };
    await tester.tap(find.text(TournamentStrings.RETRY));
    await tester.pumpAndSettle();
    expect(find.text('Sunday Cup'), findsOneWidget);
  });

  testWidgets('Join now asks for a team name before joining', (tester) async {
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [_tournamentJson()],
      },
      'GET /tournaments/7': {'tournament': _tournamentJson()},
      'POST /tournaments/7/join': {
        'tournament': _tournamentJson(currentTeams: 5, joined: true),
      },
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(TournamentStrings.JOIN_NOW));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.TEAM_NAME_TITLE), findsOneWidget);

    // Join stays disabled until the name is valid.
    await tester.tap(find.byKey(const ValueKey('tournament_confirm_join')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('POST /tournaments/7/join')));

    await tester.enterText(_teamNameField, '  Red   Lions ');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tournament_confirm_join')));
    await tester.pumpAndSettle();
    expect(api.bodies['POST /tournaments/7/join'], {'name': 'Red Lions'});
    expect(find.text(TournamentStrings.TEAM_NAME_TITLE), findsNothing);
    expect(find.byKey(const ValueKey('tournament_leave')), findsOneWidget);
    expect(find.text(TournamentStrings.JOIN_SUCCESS), findsOneWidget);
    expect(find.text('5/16 teams'), findsWidgets);
  });

  testWidgets('invalid names explain the rule and cannot be sent', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join')));
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.TEAM_NAME_RULES), findsOneWidget);
    await tester.enterText(_teamNameField, 'ab');
    await tester.pump();
    expect(find.text(TournamentStrings.TEAM_NAME_LENGTH), findsOneWidget);
    await tester.enterText(_teamNameField, '---');
    await tester.pump();
    expect(find.text(TournamentStrings.TEAM_NAME_CHARACTERS), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(api.calls, ['GET /tournaments/7']);
  });

  testWidgets('a rejected name keeps the sheet open, then refreshes', (
    tester,
  ) async {
    const taken = 'That team name is already taken in this tournament.';
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
      'POST /tournaments/7/join': const ApiException(taken, statusCode: 409),
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join')));
    await tester.pumpAndSettle();

    await tester.enterText(_teamNameField, 'Blue Lions');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(taken), findsOneWidget);
    expect(find.text(TournamentStrings.TEAM_NAME_TITLE), findsOneWidget);

    // Editing the name clears the server's message.
    await tester.enterText(_teamNameField, 'Blue Lions B');
    await tester.pump();
    expect(find.text(taken), findsNothing);

    await tester.tap(find.text(TournamentStrings.CANCEL));
    await tester.pumpAndSettle();
    expect(
      api.calls.where((call) => call == 'GET /tournaments/7'),
      hasLength(2),
    );
  });

  testWidgets('the join sheet blocks double submits while joining', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
      'POST /tournaments/7/join': {
        'tournament': _tournamentJson(currentTeams: 5, joined: true),
      },
    });
    final joinGate = Completer<void>();
    api.gates['POST /tournaments/7/join'] = joinGate;
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join')));
    await tester.pumpAndSettle();
    await tester.enterText(_teamNameField, 'Red Lions');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tournament_confirm_join')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('tournament_confirm_join')),
      warnIfMissed: false,
    );
    await tester.tap(find.text(TournamentStrings.CANCEL), warnIfMissed: false);
    await tester.pump();

    expect(
      api.calls.where((call) => call == 'POST /tournaments/7/join'),
      hasLength(1),
    );
    expect(find.text(TournamentStrings.TEAM_NAME_TITLE), findsOneWidget);
    joinGate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tournament_leave')), findsOneWidget);
  });

  testWidgets('the join sheet fits a 360-dp phone with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final control in [
      find.byKey(const ValueKey('tournament_confirm_join')),
      find.widgetWithText(TextButton, TournamentStrings.CANCEL),
    ]) {
      expect(
        tester.getSize(control).height,
        greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
      );
    }
  });

  testWidgets('cancelling the team name sheet does not join', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tournament_join')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TournamentStrings.CANCEL));
    await tester.pumpAndSettle();

    expect(api.calls, ['GET /tournaments/7']);
    expect(find.byKey(const ValueKey('tournament_join')), findsOneWidget);
  });

  testWidgets('a joined captain can leave after confirming', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(joined: true)},
      'DELETE /tournaments/7/join': {
        'tournament': _tournamentJson(currentTeams: 3),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.JOINED), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tournament_leave')));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.LEAVE_TITLE), findsOneWidget);
    expect(api.calls, isNot(contains('DELETE /tournaments/7/join')));

    await tester.tap(find.byKey(const ValueKey('tournament_confirm_leave')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE /tournaments/7/join'));
    expect(find.text(TournamentStrings.LEAVE_SUCCESS), findsOneWidget);
    expect(find.byKey(const ValueKey('tournament_join')), findsOneWidget);
    expect(find.text('3/16 teams'), findsWidgets);
  });

  testWidgets('choosing Stay keeps the team in the tournament', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(joined: true)},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tournament_leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TournamentStrings.STAY));
    await tester.pumpAndSettle();

    expect(api.calls, ['GET /tournaments/7']);
    expect(find.byKey(const ValueKey('tournament_leave')), findsOneWidget);
  });

  testWidgets('teams cannot leave once the tournament has started', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(status: 'active', joined: true),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.JOINED), findsOneWidget);
    expect(find.byKey(const ValueKey('tournament_leave')), findsNothing);
  });

  testWidgets('teams with scheduled fixtures are not offered Leave', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(joined: true, canLeave: false),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.JOINED), findsOneWidget);
    expect(find.byKey(const ValueKey('tournament_leave')), findsNothing);
  });

  testWidgets('a refused leave stays in the sheet, then refreshes', (
    tester,
  ) async {
    const started = 'You can only leave before the tournament starts.';
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(joined: true)},
      'DELETE /tournaments/7/join': const ApiException(
        started,
        statusCode: 409,
      ),
    });
    final leaveGate = Completer<void>();
    api.gates['DELETE /tournaments/7/join'] = leaveGate;
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_leave')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tournament_confirm_leave')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('tournament_confirm_leave')),
      warnIfMissed: false,
    );
    await tester.tap(find.text(TournamentStrings.STAY), warnIfMissed: false);
    await tester.pump();
    expect(
      api.calls.where((call) => call == 'DELETE /tournaments/7/join'),
      hasLength(1),
    );
    expect(find.text(TournamentStrings.LEAVE_TITLE), findsOneWidget);

    leaveGate.complete();
    await tester.pumpAndSettle();
    expect(find.text(started), findsOneWidget);

    api.responses['GET /tournaments/7'] = {
      'tournament': _tournamentJson(status: 'active', joined: true),
    };
    await tester.tap(find.text(TournamentStrings.STAY));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.JOINED), findsOneWidget);
    expect(find.byKey(const ValueKey('tournament_leave')), findsNothing);
  });

  testWidgets('leave controls are thumb sized on a 360-dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(joined: true)},
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('tournament_leave'))).height,
      greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
    );

    await tester.tap(find.byKey(const ValueKey('tournament_leave')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final control in [
      find.byKey(const ValueKey('tournament_confirm_leave')),
      find.widgetWithText(TextButton, TournamentStrings.STAY),
    ]) {
      expect(
        tester.getSize(control).height,
        greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
      );
    }
  });

  testWidgets('list badges refresh when coming back from another screen', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [_tournamentJson(joined: true, pendingRequests: 1)],
      },
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.pendingRequestsLabel(1)), findsOne);

    // Any screen pushed above the list, not only the detail screen.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    api.responses['GET /tournaments'] = {
      'tournaments': [_tournamentJson(joined: true, pendingRequests: 3)],
    };
    navigator.pop();
    await tester.pump();
    // Refreshed in place, without the skeleton.
    expect(find.byType(TournamentSkeletonList), findsNothing);
    await tester.pumpAndSettle();

    expect(api.calls.where((call) => call == 'GET /tournaments'), hasLength(2));
    expect(find.text(TournamentStrings.pendingRequestsLabel(3)), findsOne);
  });

  testWidgets('the list refreshes when the app comes back to the front', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [_tournamentJson(joined: true, pendingRequests: 1)],
      },
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pumpAndSettle();
    api.responses['GET /tournaments'] = {
      'tournaments': [_tournamentJson(joined: true, pendingRequests: 2)],
    };

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.pendingRequestsLabel(2)), findsOne);
  });

  testWidgets('captains with players transfer or disband instead of leave', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
          canDisband: true,
        ),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tournament_leave')), findsNothing);
    expect(find.byKey(const ValueKey('tournament_transfer')), findsOne);
    expect(find.byKey(const ValueKey('tournament_disband')), findsOne);
  });

  testWidgets('a captain hands the team to a player and becomes one', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
          canDisband: true,
        ),
      },
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
      'POST /tournaments/7/transfer-captaincy': {
        'tournament': _tournamentJson(myTeamId: 1, canLeave: true),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_transfer')));
    await tester.pumpAndSettle();

    // The captain is not offered, and nothing is sent before a choice.
    expect(find.byKey(const ValueKey('transfer_player_10')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('transfer_confirm')));
    await tester.pumpAndSettle();
    expect(
      api.calls,
      isNot(contains('POST /tournaments/7/transfer-captaincy')),
    );

    await tester.tap(find.byKey(const ValueKey('transfer_player_11')));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.makeCaptain('erling')), findsOne);
    await tester.tap(find.byKey(const ValueKey('transfer_confirm')));
    await tester.pumpAndSettle();

    expect(api.bodies['POST /tournaments/7/transfer-captaincy'], {
      'newCaptainId': 11,
    });
    expect(find.text(TournamentStrings.transferSuccess('erling')), findsOne);
    // Now a player: captain controls are gone and Leave team is offered.
    expect(find.byKey(const ValueKey('tournament_transfer')), findsNothing);
    expect(
      find.byKey(const ValueKey('tournament_join_requests')),
      findsNothing,
    );
    expect(find.text(TournamentStrings.LEAVE_TEAM), findsOne);
  });

  testWidgets('a refused transfer stays in the sheet, then refreshes', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
        ),
      },
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
      'POST /tournaments/7/transfer-captaincy': const ApiException(
        'Player not found on this team.',
        statusCode: 404,
      ),
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer_player_11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Player not found on this team.'), findsOne);
    await tester.tap(find.byTooltip(TournamentStrings.CLOSE));
    await tester.pumpAndSettle();
    expect(
      api.calls.where((call) => call == 'GET /tournaments/7'),
      hasLength(2),
    );
  });

  testWidgets('a captain disbands the team after confirming', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
          canDisband: true,
          teams: [
            {'id': 1, 'name': 'Blue Lions', 'players': 3},
          ],
        ),
      },
      'DELETE /tournaments/7/join?disband=true': {
        'tournament': _tournamentJson(currentTeams: 3, teams: []),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_disband')));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.DISBAND_TITLE), findsOne);
    expect(
      find.text(TournamentStrings.confirmDisbandMessage('Blue Lions', 2)),
      findsOne,
    );

    await tester.tap(find.text(TournamentStrings.KEEP));
    await tester.pumpAndSettle();
    expect(api.calls.where((call) => call.startsWith('DELETE')), isEmpty);

    await tester.tap(find.byKey(const ValueKey('tournament_disband')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_confirm_disband')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE /tournaments/7/join?disband=true'));
    expect(find.text(TournamentStrings.DISBAND_SUCCESS), findsOne);
    expect(find.byKey(const ValueKey('tournament_join')), findsOne);
  });

  testWidgets('players leave their team, not the tournament', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(myTeamId: 1, canLeave: true),
      },
      'DELETE /tournaments/7/join': {'tournament': _tournamentJson()},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.LEAVE_TEAM), findsOne);
    await tester.tap(find.byKey(const ValueKey('tournament_leave')));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.LEAVE_TEAM_TITLE), findsOne);
    expect(
      find.text(TournamentStrings.confirmLeaveTeamMessage('Blue Lions')),
      findsOne,
    );
    await tester.tap(
      find.byKey(const ValueKey('tournament_confirm_leave_team')),
    );
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE /tournaments/7/join'));
    expect(find.text(TournamentStrings.LEAVE_TEAM_SUCCESS), findsOne);
  });

  testWidgets('captain controls are thumb sized on a 360-dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
          canDisband: true,
          pendingRequests: 2,
        ),
      },
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final key in ['tournament_transfer', 'tournament_disband']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
        reason: key,
      );
    }

    await tester.tap(find.byKey(const ValueKey('tournament_transfer')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final key in ['transfer_player_11', 'transfer_confirm']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
        reason: key,
      );
    }
  });

  testWidgets('a transfer to a withdrawn team explains the real reason', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
        ),
      },
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
      'POST /tournaments/7/transfer-captaincy': const ApiException(
        'Your team is no longer in this tournament.',
        statusCode: 409,
        code: TournamentErrorCodes.TEAM_WITHDRAWN,
      ),
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer_player_11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer_confirm')));
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.TRANSFER_TEAM_WITHDRAWN), findsOne);
    expect(find.text(TournamentStrings.TRANSFER_CLOSED), findsNothing);
  });

  testWidgets('the transfer sheet cannot be swiped away mid-request', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
        ),
      },
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
      'POST /tournaments/7/transfer-captaincy': {
        'tournament': _tournamentJson(myTeamId: 1, canLeave: true),
      },
    });
    final gate = api.gates['POST /tournaments/7/transfer-captaincy'] =
        Completer<void>();
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer_player_11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer_confirm')));
    await tester.pump();

    await tester.fling(_transferSheetTitle, const Offset(0, 500), 2000);
    // The spinner keeps animating, so pump a fixed time well under the
    // request timeout instead of settling.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(TournamentStrings.TRANSFER_HINT), findsOne);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.TRANSFER_HINT), findsNothing);
    expect(find.text(TournamentStrings.transferSuccess('erling')), findsOne);
  });

  testWidgets('the transfer sheet can be swiped away when idle', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          joined: true,
          canLeave: false,
          canTransfer: true,
        ),
      },
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_transfer')));
    await tester.pumpAndSettle();
    await tester.fling(_transferSheetTitle, const Offset(0, 500), 2000);
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.TRANSFER_HINT), findsNothing);
  });

  testWidgets('former players see once that their team was disbanded', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(teamDisbanded: true),
      },
      'DELETE /tournaments/7/disband-notice': <String, Object?>{},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.TEAM_DISBANDED_NOTICE), findsOne);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('tournament_disbanded_notice')))
          .height,
      greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
    );

    await tester.tap(find.byKey(const ValueKey('tournament_disbanded_notice')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE /tournaments/7/disband-notice'));
    expect(find.text(TournamentStrings.TEAM_DISBANDED_NOTICE), findsNothing);
  });

  testWidgets('a notice that fails to dismiss comes back with the reason', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(teamDisbanded: true),
      },
      'DELETE /tournaments/7/disband-notice': const ApiException(
        'Tournament not found.',
        statusCode: 404,
      ),
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_disbanded_notice')));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.TEAM_DISBANDED_NOTICE), findsOne);
    expect(find.text('Tournament not found.'), findsOne);
  });

  testWidgets('the disbanded notice fits a 360-dp phone at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(teamDisbanded: true),
      },
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(TournamentStrings.TEAM_DISBANDED_NOTICE), findsOne);
    expect(find.byKey(const ValueKey('tournament_join')), findsOne);
  });

  testWidgets('a player requests to join a team and sees it pending', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
      'POST /tournaments/7/teams/1/request': {
        'tournament': _tournamentJson(
          myRequests: [
            {'teamId': 1, 'status': 'pending'},
          ],
        ),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.TEAMS));
    await tester.pumpAndSettle();
    expect(find.text('1/5 players'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team_request_1')));
    await tester.pumpAndSettle();

    expect(api.calls, contains('POST /tournaments/7/teams/1/request'));
    expect(find.text(TournamentStrings.REQUEST_SENT), findsOneWidget);
    expect(find.text(TournamentStrings.REQUEST_PENDING), findsOneWidget);
    expect(find.byKey(const ValueKey('team_request_1')), findsNothing);
  });

  testWidgets('request buttons hide for players who have a team', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          myTeamId: 2,
          teams: [
            {'id': 1, 'name': 'Blue Lions', 'players': 1},
            {'id': 2, 'name': 'Red Hawks', 'players': 2},
          ],
        ),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.TEAM_MEMBER), findsOneWidget);
    expect(find.byKey(const ValueKey('tournament_join')), findsNothing);

    await tester.tap(find.widgetWithText(Tab, TournamentStrings.TEAMS));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.YOUR_TEAM), findsOneWidget);
    expect(find.text(TournamentStrings.REQUEST_TO_JOIN), findsNothing);
  });

  testWidgets('full and declined teams cannot be asked again', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          teamSize: 2,
          teams: [
            {'id': 1, 'name': 'Blue Lions', 'players': 1},
            {'id': 2, 'name': 'Red Hawks', 'players': 2},
            {'id': 3, 'name': 'Green Owls', 'players': 1},
          ],
          myRequests: [
            {'teamId': 1, 'status': 'declined'},
          ],
        ),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.TEAMS));
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.REQUEST_DECLINED), findsOneWidget);
    expect(find.text(TournamentStrings.TEAM_FULL), findsOneWidget);
    expect(find.byKey(const ValueKey('team_request_1')), findsNothing);
    expect(find.byKey(const ValueKey('team_request_2')), findsNothing);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('team_request_3')),
      find.byType(ListView).last,
      const Offset(0, -80),
    );
    expect(find.byKey(const ValueKey('team_request_3')), findsOneWidget);
  });

  testWidgets('an unanswered request shows as expired after kickoff', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          status: 'active',
          myRequests: [
            {'teamId': 1, 'status': 'expired'},
          ],
        ),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.TEAMS));
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.REQUEST_EXPIRED), findsOneWidget);
    expect(find.byKey(const ValueKey('team_request_1')), findsNothing);
  });

  testWidgets('a captain accepts a request from the requests sheet', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(joined: true, pendingRequests: 2),
      },
      'GET /tournaments/7/requests': {
        'requests': [_requestJson(), _requestJson(id: 32, requester: 'kylian')],
      },
      'PUT /tournaments/7/requests/31': {
        'request': {..._requestJson(), 'status': 'accepted'},
      },
      'PUT /tournaments/7/requests/32': const ApiException(
        'Your team is full.',
        statusCode: 409,
      ),
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tournament_join_requests')));
    await tester.pumpAndSettle();
    expect(find.text('erling'), findsOneWidget);
    expect(find.text('Sent Oct 11'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('request_accept_31')));
    await tester.pumpAndSettle();
    expect(api.bodies['PUT /tournaments/7/requests/31'], {
      'status': 'accepted',
    });
    expect(find.text('erling'), findsNothing);
    expect(find.text(TournamentStrings.REQUEST_ACCEPTED), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('request_accept_32')));
    await tester.pumpAndSettle();
    expect(find.text('Your team is full.'), findsOneWidget);
    expect(find.text('kylian'), findsOneWidget);

    await tester.tap(find.byTooltip(TournamentStrings.CLOSE));
    await tester.pumpAndSettle();
    expect(
      api.calls.where((call) => call == 'GET /tournaments/7'),
      hasLength(2),
    );
  });

  testWidgets('dismissing the requests sheet still refreshes the screen', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(joined: true, pendingRequests: 1),
      },
      'GET /tournaments/7/requests': {
        'requests': [_requestJson()],
      },
      'PUT /tournaments/7/requests/31': {
        'request': {..._requestJson(), 'status': 'accepted'},
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join_requests')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('request_accept_31')));
    await tester.pumpAndSettle();

    api.responses['GET /tournaments/7'] = {
      'tournament': _tournamentJson(joined: true, canLeave: false),
    };
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.JOIN_REQUESTS), findsOneWidget);
    expect(
      api.calls.where((call) => call == 'GET /tournaments/7'),
      hasLength(2),
    );
    expect(find.byKey(const ValueKey('tournament_leave')), findsNothing);
  });

  testWidgets('the requests sheet shows an empty state and fits 360 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(joined: true)},
      'GET /tournaments/7/requests': {
        'requests': [_requestJson(requester: 'a_very_long_username_')],
      },
      'PUT /tournaments/7/requests/31': {
        'request': {..._requestJson(), 'status': 'declined'},
      },
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('tournament_join_requests')))
          .height,
      greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
    );

    await tester.tap(find.byKey(const ValueKey('tournament_join_requests')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final key in ['request_accept_31', 'request_decline_31']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
      );
    }

    await tester.tap(find.byKey(const ValueKey('request_decline_31')));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.JOIN_REQUESTS_EMPTY), findsOneWidget);
  });

  testWidgets('list cards show waiting requests to captains', (tester) async {
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [
          _tournamentJson(joined: true, pendingRequests: 2),
          _tournamentJson(id: 8, name: 'Quiet Cup', joined: true),
        ],
      },
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api))),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 requests'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tournament_requests_badge')),
      findsOneWidget,
    );
  });

  testWidgets('the join sheet warns that a pending request is cancelled', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(
          myRequests: [
            {'teamId': 1, 'status': 'pending'},
          ],
        ),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This will cancel your pending request to Blue Lions. Continue?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the join sheet has no warning without a pending request', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('join_pending_warning')), findsNothing);
  });

  testWidgets('View team shows the roster and stats to any player', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson()},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.TEAMS));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('team_view_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team_view_1')));
    await tester.pumpAndSettle();

    expect(find.text('Captain: captain_kai'), findsOneWidget);
    expect(find.text('erling'), findsOneWidget);
    expect(find.text('Lv 2 · 350 XP · 🔥 4'), findsNWidgets(2));
    await tester.dragUntilVisible(
      find.text(TournamentStrings.NO_MATCHES_PLAYED),
      find.byType(ListView).last,
      const Offset(0, -80),
    );
    expect(find.text('700'), findsOneWidget);
    expect(find.text(TournamentStrings.NO_MATCHES_PLAYED), findsOneWidget);
    expect(find.byKey(const ValueKey('team_remove_11')), findsNothing);
  });

  testWidgets('a captain removes a player after confirming', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(joined: true)},
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson(canManage: true)},
      'DELETE /tournaments/7/teams/1/members/11': {
        'team': _teamDetailsJson(
          canManage: true,
          players: [
            _playerJson(id: 10, username: 'captain_kai', isCaptain: true),
          ],
        ),
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.TEAMS));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('team_view_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team_view_1')));
    await tester.pumpAndSettle();

    // The captain cannot remove themselves.
    expect(find.byKey(const ValueKey('team_remove_10')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('team_remove_11')));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.REMOVE_PLAYER_TITLE), findsOneWidget);

    await tester.tap(find.text(TournamentStrings.KEEP));
    await tester.pumpAndSettle();
    expect(
      api.calls,
      isNot(contains('DELETE /tournaments/7/teams/1/members/11')),
    );

    await tester.tap(find.byKey(const ValueKey('team_remove_11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team_confirm_remove')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE /tournaments/7/teams/1/members/11'));
    expect(find.text('erling'), findsNothing);
    expect(find.text(TournamentStrings.PLAYER_REMOVED), findsOneWidget);

    await tester.tap(find.byTooltip(TournamentStrings.CLOSE));
    await tester.pumpAndSettle();
    expect(
      api.calls.where((call) => call == 'GET /tournaments/7'),
      hasLength(2),
    );
  });

  testWidgets('a captain views a requester profile from the requests sheet', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(joined: true, pendingRequests: 1),
      },
      'GET /tournaments/7/requests': {
        'requests': [_requestJson()],
      },
      'GET /users/131/profile': {'profile': _profileJson()},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join_requests')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('request_profile_31')));
    await tester.pumpAndSettle();

    expect(find.text('RISING STAR · Level 3'), findsOneWidget);
    expect(find.text('650'), findsOneWidget);
    expect(find.text('🔥 4'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('FIRST KICKOFF'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('3 – 1'),
      find.byType(ListView).last,
      const Offset(0, -80),
    );
    expect(find.text('3 – 1'), findsOneWidget);
    expect(find.text('vs Red Hawks · City League · Nov 2'), findsOneWidget);

    // Closing the profile returns to the requests list.
    await tester.tap(find.byTooltip(TournamentStrings.CLOSE).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('request_accept_31')), findsOneWidget);
  });

  testWidgets('profiles without matches or achievements say so', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(joined: true, pendingRequests: 1),
      },
      'GET /tournaments/7/requests': {
        'requests': [_requestJson()],
      },
      'GET /users/131/profile': {'profile': _profileJson(empty: true)},
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tournament_join_requests')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('request_profile_31'))).height,
      greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
    );
    await tester.tap(find.byKey(const ValueKey('request_profile_31')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(TournamentStrings.PROFILE_NO_ACHIEVEMENTS),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.text(TournamentStrings.NO_MATCHES_PLAYED),
      find.byType(ListView).last,
      const Offset(0, -80),
    );
    expect(find.text(TournamentStrings.NO_MATCHES_PLAYED), findsOneWidget);
  });

  testWidgets('team sheet controls are thumb sized on a 360-dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(joined: true)},
      'GET /tournaments/7/teams/1': {'team': _teamDetailsJson(canManage: true)},
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.TEAMS));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('team_view_1'))).height,
      greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('team_view_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team_view_1')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('team_remove_11')),
      find.byType(ListView).last,
      const Offset(0, -80),
    );
    final remove = tester.getSize(find.byKey(const ValueKey('team_remove_11')));
    expect(remove.height, greaterThanOrEqualTo(TournamentSizes.MIN_TAP));
    expect(remove.width, greaterThanOrEqualTo(TournamentSizes.MIN_TAP));
  });

  testWidgets('detail tabs follow the tournament format', (tester) async {
    const expected = {
      'league': [TournamentStrings.STANDINGS],
      'round_robin': [TournamentStrings.STANDINGS],
      'knockout': [TournamentStrings.BRACKET],
      'groups_knockout': [
        TournamentStrings.STANDINGS,
        TournamentStrings.BRACKET,
      ],
    };
    for (final MapEntry(key: format, value: extraTabs) in expected.entries) {
      final api = _FakeApi({
        'GET /tournaments/7': {'tournament': _tournamentJson(format: format)},
      });
      await tester.pumpWidget(
        _app(
          TournamentDetailScreen(
            key: ValueKey(format),
            service: _service(api),
            tournamentId: 7,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<Tab>(find.byType(Tab))
          .map((tab) => tab.text)
          .toList();
      expect(labels, [
        TournamentStrings.ABOUT,
        TournamentStrings.TEAMS,
        ...extraTabs,
      ], reason: format);
    }
  });

  testWidgets('four tabs stay readable on a 360-dp phone at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(format: 'groups_knockout'),
      },
      'GET /tournaments/7/bracket': {
        'bracket': {'rounds': <Object>[]},
      },
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Each label is laid out on one line at full width.
    for (final label in [
      TournamentStrings.ABOUT,
      TournamentStrings.TEAMS,
      TournamentStrings.STANDINGS,
      TournamentStrings.BRACKET,
    ]) {
      final text = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.widgetWithText(Tab, label),
          matching: find.text(label),
        ),
      );
      expect(text.didExceedMaxLines, isFalse, reason: label);
      expect(
        text.size.width,
        greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity) - 0.5),
        reason: label,
      );
    }
    // The tab bar scrolls to reach the last tab.
    await tester.ensureVisible(
      find.widgetWithText(Tab, TournamentStrings.BRACKET),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.BRACKET));
    await tester.pumpAndSettle();
    expect(find.text(TournamentStrings.EMPTY_BRACKET), findsOneWidget);
  });

  testWidgets('the bracket shows rounds, winners, byes and open slots', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(format: 'knockout')},
      'GET /tournaments/7/bracket': _bracketJson(),
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.BRACKET));
    await tester.pumpAndSettle();

    expect(api.calls, contains('GET /tournaments/7/bracket'));
    expect(find.text(TournamentStrings.ROUND_SEMI_FINALS), findsOneWidget);
    expect(find.text(TournamentStrings.ROUND_FINAL), findsOneWidget);
    expect(find.text(TournamentStrings.BYE), findsOneWidget);
    expect(find.text(TournamentStrings.MATCH_PENALTIES), findsOneWidget);
    expect(find.text(TournamentStrings.MATCH_ADVANCES), findsOneWidget);
    // Two winners so far: Red Hawks on penalties and Green Owls on a bye.
    expect(_bracketTrophies, findsNWidgets(2));
    expect(
      find.bySemanticsLabel(
        'Semi-finals, match 1: Blue Lions 1, Red Hawks 1. Red Hawks advances.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Final, match 1: Red Hawks versus Green Owls.'),
      findsOneWidget,
    );
  });

  testWidgets('open bracket slots read TBD', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(format: 'knockout')},
      'GET /tournaments/7/bracket': {
        'bracket': {
          'rounds': [
            {
              'round': 1,
              'roundsFromEnd': 0,
              'matches': [
                _bracketMatchJson(
                  position: 1,
                  home: _bracketTeam(1, 'Blue Lions'),
                  status: 'pending',
                ),
              ],
            },
          ],
        },
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.BRACKET));
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.TBD), findsOneWidget);
    expect(find.text(TournamentStrings.MATCH_NOT_SCHEDULED), findsOneWidget);
    expect(_bracketTrophies, findsNothing);
  });

  testWidgets('a bracket without matches shows the empty state', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(format: 'knockout')},
      'GET /tournaments/7/bracket': {
        'bracket': {'rounds': <Object>[]},
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.BRACKET));
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.EMPTY_BRACKET), findsOneWidget);
    expect(find.text(TournamentStrings.EMPTY_BRACKET_HINT), findsOneWidget);
  });

  testWidgets('a 16-team bracket fits a 360-dp phone at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rounds = [
      for (var round = 0; round < 4; round++)
        {
          'round': round + 1,
          'roundsFromEnd': 3 - round,
          'matches': [
            for (var slot = 0; slot < 8 >> round; slot++)
              _bracketMatchJson(
                position: slot + 1,
                home: round == 0
                    ? _bracketTeam(slot * 2 + 1, 'Northside Rovers ${slot}A')
                    : null,
                away: round == 0
                    ? _bracketTeam(slot * 2 + 2, 'Southside United ${slot}B')
                    : null,
                status: round == 0 ? 'scheduled' : 'pending',
              ),
          ],
        },
    ];
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(format: 'knockout')},
      'GET /tournaments/7/bracket': {
        'bracket': {'rounds': rounds},
      },
    });
    await tester.pumpWidget(
      _app(
        TournamentDetailScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.BRACKET));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(TournamentStrings.ROUND_OF_16), findsOneWidget);
    // The tree scrolls sideways to the final.
    await tester.dragUntilVisible(
      find.text(TournamentStrings.ROUND_FINAL),
      find.byType(SingleChildScrollView).last,
      const Offset(-150, 0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups + knockout standings show one table per group', (
    tester,
  ) async {
    final api = _FakeApi({
      'GET /tournaments/7': {
        'tournament': _tournamentJson(format: 'groups_knockout'),
      },
      'GET /tournaments/7/standings': {
        'standings': [
          {..._standingJson(position: 1, teamName: 'Beta One'), 'group': 'B'},
          {..._standingJson(position: 2, teamName: 'Alpha Two'), 'group': 'A'},
          {..._standingJson(position: 1, teamName: 'Alpha One'), 'group': 'A'},
        ],
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, TournamentStrings.STANDINGS));
    await tester.pumpAndSettle();

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Group A'), lessThan(top('Alpha One')));
    expect(top('Alpha One'), lessThan(top('Alpha Two')));

    await tester.dragUntilVisible(
      find.text('Beta One'),
      find.byType(ListView).last,
      const Offset(0, -80),
    );
    expect(top('Alpha Two'), lessThan(top('Group B')));
    expect(top('Group B'), lessThan(top('Beta One')));
  });

  testWidgets('full tournaments cannot be joined', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson(currentTeams: 16)},
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();

    expect(find.text(TournamentStrings.FULL), findsOneWidget);
    expect(find.text(TournamentStrings.STATUS_FULL), findsOneWidget);
    expect(find.byKey(const ValueKey('tournament_join')), findsNothing);
  });

  testWidgets('detail Standings tab loads the table', (tester) async {
    final api = _FakeApi({
      'GET /tournaments/7': {'tournament': _tournamentJson()},
      'GET /tournaments/7/standings': {
        'standings': [_standingJson(position: 1, teamName: 'Blue Lions')],
      },
    });
    await tester.pumpWidget(
      _app(TournamentDetailScreen(service: _service(api), tournamentId: 7)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(TournamentStrings.STANDINGS));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GET /tournaments/7/standings'));
    expect(find.text('🥇'), findsOneWidget);
  });

  testWidgets('standings show medals and fit a 360-dp phone at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments/7/standings': {
        'standings': [
          _standingJson(position: 2, teamName: 'Blue Lions', isUserTeam: true),
          _standingJson(position: 1, teamName: 'Northside Rovers United FC'),
          _standingJson(position: 3, teamName: 'Park Rangers'),
          _standingJson(position: 4, teamName: 'City United'),
        ],
      },
    });
    await tester.pumpWidget(
      _app(
        TournamentStandingsScreen(service: _service(api), tournamentId: 7),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final medal in TournamentStrings.MEDALS) {
      expect(find.text(medal), findsOneWidget);
    }
    expect(find.text('4'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Northside Rovers United FC')).dy,
      lessThan(tester.getTopLeft(find.text('Blue Lions')).dy),
    );
  });

  testWidgets('list controls are thumb sized on a 360-dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi({
      'GET /tournaments': {
        'tournaments': [
          _tournamentJson(name: 'A very long tournament name for small phones'),
        ],
      },
    });
    await tester.pumpWidget(
      _app(TournamentsListScreen(service: _service(api)), textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final label in [
      TournamentStrings.JOIN_NOW,
      TournamentStrings.FILTER_ALL,
    ]) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(button.first).height,
        greaterThanOrEqualTo(TournamentSizes.MIN_TAP),
      );
    }
  });
}

TournamentService _service(_FakeApi api) => TournamentService(api);

/// The transfer sheet's title, outside its scrolling list (the disabled
/// confirm button shares the label, below it).
Finder get _transferSheetTitle => find
    .descendant(
      of: find.byType(TournamentSheetFrame),
      matching: find.text(TournamentStrings.TRANSFER_CAPTAINCY),
    )
    .first;

Finder get _teamNameField => find.descendant(
  of: find.byKey(const ValueKey('tournament_team_name')),
  matching: find.byType(EditableText),
);

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  navigatorObservers: [appRouteObserver],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

Map<String, Object?> _tournamentJson({
  int id = 7,
  String name = 'Sunday Cup',
  String format = 'league',
  String status = 'upcoming',
  int currentTeams = 4,
  bool joined = false,
  bool? canLeave,
  bool canTransfer = false,
  bool canDisband = false,
  bool teamDisbanded = false,
  int? myTeamId,
  int pendingRequests = 0,
  int teamSize = 5,
  List<Map<String, Object?>>? teams,
  List<Map<String, Object?>> myRequests = const [],
}) => {
  'id': id,
  'name': name,
  'description': 'Weekend league.',
  'format': format,
  'status': status,
  'startDate': '2026-11-01T10:00:00',
  'endDate': '2026-11-02T18:00:00',
  'maxTeams': 16,
  'currentTeams': currentTeams,
  'location': 'City Park',
  'createdBy': 'organizer',
  'joined': joined,
  'canLeave': canLeave ?? (joined && status == 'upcoming'),
  'canTransfer': canTransfer,
  'canDisband': canDisband,
  'teamDisbanded': teamDisbanded,
  'teamSize': teamSize,
  'myTeamId': myTeamId ?? (joined ? 1 : null),
  'pendingRequests': pendingRequests,
  'prize': null,
  'teams':
      teams ??
      [
        {'id': 1, 'name': 'Blue Lions', 'players': 1},
      ],
  'myRequests': myRequests,
};

/// Winner trophies inside the bracket (the hero has its own trophy).
Finder get _bracketTrophies => find.descendant(
  of: find.byType(BracketWidget),
  matching: find.byIcon(Icons.emoji_events_rounded),
);

Map<String, Object?> _bracketTeam(int id, String name) => {
  'id': id,
  'name': name,
};

Map<String, Object?> _bracketMatchJson({
  required int position,
  int? id,
  Map<String, Object?>? home,
  Map<String, Object?>? away,
  int? homeScore,
  int? awayScore,
  int? winnerId,
  String status = 'scheduled',
}) => {
  'id': id,
  'position': position,
  'home': home,
  'away': away,
  'homeScore': homeScore,
  'awayScore': awayScore,
  'status': status,
  'winnerId': winnerId,
  'scheduledAt': null,
};

/// Semi-finals (one decided on penalties, one bye) and a final in which one
/// side is known.
Map<String, Object?> _bracketJson() => {
  'bracket': {
    'rounds': [
      {
        'round': 1,
        'roundsFromEnd': 1,
        'matches': [
          _bracketMatchJson(
            id: 1,
            position: 1,
            home: _bracketTeam(1, 'Blue Lions'),
            away: _bracketTeam(2, 'Red Hawks'),
            homeScore: 1,
            awayScore: 1,
            winnerId: 2,
            status: 'played',
          ),
          _bracketMatchJson(
            id: 2,
            position: 2,
            home: _bracketTeam(3, 'Green Owls'),
            winnerId: 3,
            status: 'bye',
          ),
        ],
      },
      {
        'round': 2,
        'roundsFromEnd': 0,
        'matches': [
          _bracketMatchJson(
            position: 1,
            home: _bracketTeam(2, 'Red Hawks'),
            away: _bracketTeam(3, 'Green Owls'),
            status: 'pending',
          ),
        ],
      },
    ],
  },
};

Map<String, Object?> _teamDetailsJson({
  bool canManage = false,
  List<Map<String, Object?>>? players,
  int played = 0,
}) => {
  'id': 1,
  'name': 'Blue Lions',
  'captainId': 10,
  'captainName': 'captain_kai',
  'teamSize': 5,
  'canManage': canManage,
  'players':
      players ??
      [
        _playerJson(id: 10, username: 'captain_kai', isCaptain: true),
        _playerJson(id: 11, username: 'erling'),
      ],
  'stats': {
    'players': (players?.length ?? 2),
    'totalXp': 700,
    'averageLevel': 2,
    'played': played,
    'wins': played,
    'draws': 0,
    'losses': 0,
    'goalsFor': 3 * played,
    'goalsAgainst': played,
    'points': 3 * played,
  },
};

Map<String, Object?> _playerJson({
  required int id,
  required String username,
  bool isCaptain = false,
}) => {
  'id': id,
  'username': username,
  'xp': 350,
  'level': 2,
  'currentStreak': 4,
  'isCaptain': isCaptain,
};

Map<String, Object?> _profileJson({bool empty = false}) => {
  'id': 131,
  'username': 'erling',
  'xp': 650,
  'level': 3,
  'rank': 'RISING STAR',
  'currentStreak': 4,
  'bestStreak': 9,
  'achievements': empty
      ? <Object>[]
      : [
          {
            'code': 'first_kickoff',
            'title': 'FIRST KICKOFF',
            'icon': 'whistle',
            'unlockedAt': '2026-10-01 10:00:00',
          },
        ],
  'recentMatches': empty
      ? <Object>[]
      : [
          {
            'tournamentName': 'City League',
            'teamName': 'Blue Lions',
            'opponentName': 'Red Hawks',
            'goalsFor': 3,
            'goalsAgainst': 1,
            'result': 'win',
            'playedAt': '2026-11-02T10:00:00Z',
          },
        ],
};

Map<String, Object?> _requestJson({int id = 31, String requester = 'erling'}) =>
    {
      'id': id,
      'teamId': 1,
      'teamName': 'Blue Lions',
      'requesterId': id + 100,
      'requesterName': requester,
      'status': 'pending',
      'createdAt': '2026-10-11 15:35:09',
    };

Map<String, Object?> _standingJson({
  required int position,
  required String teamName,
  bool isUserTeam = false,
}) => {
  'position': position,
  'teamId': position,
  'teamName': teamName,
  'played': 3,
  'wins': 2,
  'draws': 0,
  'losses': 1,
  'goalsFor': 7,
  'goalsAgainst': 3,
  'goalDifference': 4,
  'points': 6,
  'isUserTeam': isUserTeam,
};

/// Answers authenticated requests from canned responses keyed by
/// `METHOD /path`. A response that is an [Exception] or [Error] is thrown.
/// When [gate] is given, responses wait for it to complete.
class _FakeApi extends Fake implements ApiClient {
  _FakeApi(this.responses, {this.gate});

  final Map<String, Object> responses;
  final Completer<void>? gate;

  /// Per-request gates, keyed like [responses].
  final gates = <String, Completer<void>>{};
  final calls = <String>[];
  final bodies = <String, Map<String, Object?>?>{};

  @override
  Future<Map<String, dynamic>> sendAuthenticated(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final key = '$method $path';
    calls.add(key);
    bodies[key] = body;
    await gate?.future;
    await gates[key]?.future;
    final response = responses[key];
    if (response is Exception || response is Error) throw response!;
    if (response == null) throw ApiException('No fake for $key');
    return Map<String, dynamic>.from(response as Map);
  }
}
