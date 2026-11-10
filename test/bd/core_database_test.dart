import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/api_client.dart';
import 'package:football_match_app/bd/core_database.dart';
import 'package:football_match_app/services/tournament/tournament_service.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.responses)
      : super(
          baseUrl: 'http://example.com',
          client: null,
          storage: null,
        );

  final Map<String, Object> responses;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> sendAuthenticated(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final key = '$method $path';
    calls.add(key);
    final response = responses[key];
    if (response is Exception) throw response;
    if (response is Error) throw response;
    if (response is Map<String, dynamic>) return response;
    throw ApiException('Unmatched test route: $key');
  }
}

Map<String, dynamic> _sampleTournamentJson({int id = 1, String name = 'Test Cup'}) => {
      'id': id,
      'name': name,
      'format': 'league',
      'status': 'upcoming',
      'teamSize': 5,
      'maxTeams': 8,
      'currentTeams': 4,
      'startDate': '2026-12-01T00:00:00.000Z',
      'endDate': '2026-12-05T00:00:00.000Z',
      'canJoin': true,
      'joined': false,
      'spotsLeft': 4,
    };

void main() {
  setUp(() async {
    await LocalDatabase.instance.clearCache();
  });

  group('LocalDatabase', () {
    test('is a singleton', () {
      expect(identical(LocalDatabase.instance, LocalDatabase()), isTrue);
    });

    test('cacheTournaments stores and getCachedTournaments retrieves items', () async {
      final sample = [
        _sampleTournamentJson(id: 1, name: 'Cup 1'),
        _sampleTournamentJson(id: 2, name: 'Cup 2'),
      ];

      await LocalDatabase.instance.cacheTournaments(sample);
      final cached = await LocalDatabase.instance.getCachedTournaments();

      expect(cached.length, 2);
      expect(cached[0]['name'], 'Cup 1');
      expect(cached[1]['name'], 'Cup 2');
    });

    test('cacheTournaments clears existing items before inserting new ones', () async {
      await LocalDatabase.instance.cacheTournaments([
        _sampleTournamentJson(id: 1, name: 'Old Cup'),
      ]);

      await LocalDatabase.instance.cacheTournaments([
        _sampleTournamentJson(id: 2, name: 'New Cup'),
      ]);

      final cached = await LocalDatabase.instance.getCachedTournaments();
      expect(cached.length, 1);
      expect(cached[0]['name'], 'New Cup');
    });
  });

  group('TournamentService Offline-First Caching', () {
    test('caches tournaments on successful response when offset == 0', () async {
      final api = _FakeApi({
        'GET /tournaments': {
          'tournaments': [_sampleTournamentJson(id: 10, name: 'Cached Cup')],
          'hasMore': false,
        },
      });

      final service = TournamentService(api);
      final result = await service.getTournaments();

      expect(result.tournaments.single.name, 'Cached Cup');

      final cached = await LocalDatabase.instance.getCachedTournaments();
      expect(cached.length, 1);
      expect(cached.single['name'], 'Cached Cup');
    });

    test('does not overwrite cache when offset > 0 (pagination)', () async {
      await LocalDatabase.instance.cacheTournaments([
        _sampleTournamentJson(id: 1, name: 'Initial Cup'),
      ]);

      final api = _FakeApi({
        'GET /tournaments?offset=5': {
          'tournaments': [_sampleTournamentJson(id: 2, name: 'Page 2 Cup')],
          'hasMore': false,
        },
      });

      final service = TournamentService(api);
      final result = await service.getTournaments(offset: 5);

      expect(result.tournaments.single.name, 'Page 2 Cup');

      // Cache should still hold initial cup
      final cached = await LocalDatabase.instance.getCachedTournaments();
      expect(cached.single['name'], 'Initial Cup');
    });

    test('returns cached tournaments on network failure when cache has data', () async {
      await LocalDatabase.instance.cacheTournaments([
        _sampleTournamentJson(id: 42, name: 'Offline Saved Cup'),
      ]);

      final api = _FakeApi({
        'GET /tournaments': const ApiException('Connection refused'),
      });

      final service = TournamentService(api);
      final result = await service.getTournaments();

      expect(result.tournaments.length, 1);
      expect(result.tournaments.first.id, 42);
      expect(result.tournaments.first.name, 'Offline Saved Cup');
      expect(result.hasMore, isFalse);
    });

    test('rethrows exception on network failure when cache is empty', () async {
      final api = _FakeApi({
        'GET /tournaments': const ApiException('Server error', statusCode: 500),
      });

      final service = TournamentService(api);

      await expectLater(
        service.getTournaments(),
        throwsA(isA<TournamentException>()),
      );
    });
  });
}
