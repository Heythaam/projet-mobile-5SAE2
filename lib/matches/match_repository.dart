import 'football_match.dart';

abstract interface class MatchRepository {
  Future<List<FootballMatch>> listMatches();
}

class EmptyMatchRepository implements MatchRepository {
  const EmptyMatchRepository();

  @override
  Future<List<FootballMatch>> listMatches() async =>
      const <FootballMatch>[];
}
