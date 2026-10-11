import 'dart:io';

import 'package:shelf/shelf_io.dart';

import 'package:backend/app.dart';
import 'package:backend/database.dart';

void main(List<String> args) async {
  final secret = Platform.environment['JWT_SECRET'];
  if (secret == null || secret.length < 32) {
    stderr.writeln(
      'Set JWT_SECRET to a random value of at least 32 characters.',
    );
    exitCode = 1;
    return;
  }
  final database = AppDatabase(
    Platform.environment['DB_PATH'] ?? 'data/football_matches.sqlite',
  );
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(
    createApp(database: database, jwtSecret: secret),
    InternetAddress.anyIPv4,
    port,
  );
  print('Server listening on port ${server.port}');
}
