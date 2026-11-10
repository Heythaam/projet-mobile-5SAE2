import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class LiveTournamentHub {
  final Map<int, Set<WebSocketChannel>> _channels = {};

  void addConnection(int tournamentId, WebSocketChannel channel) {
    _channels.putIfAbsent(tournamentId, () => {}).add(channel);
    channel.stream.listen(
      (_) {},
      onDone: () => _channels[tournamentId]?.remove(channel),
      onError: (_) => _channels[tournamentId]?.remove(channel),
      cancelOnError: true,
    );
  }

  void broadcast(int tournamentId, Map<String, dynamic> data) {
    final msg = jsonEncode(data);
    final active = _channels[tournamentId];
    if (active == null) return;
    for (final channel in active.toList()) {
      try {
        channel.sink.add(msg);
      } catch (_) {
        active.remove(channel);
      }
    }
  }

  int connectionCount(int tournamentId) => _channels[tournamentId]?.length ?? 0;
}
