import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Who Google says the signed-in person is.
typedef GoogleIdentity = ({String email, bool emailVerified});

/// Checks a Google ID token and returns the identity, or null when invalid.
typedef GoogleVerifier = Future<GoogleIdentity?> Function(String idToken);

/// Asks Google to validate the token. When `GOOGLE_CLIENT_ID` is set the token
/// must also have been issued for that client.
Future<GoogleIdentity?> verifyGoogleIdToken(String idToken) async {
  try {
    final response = await http
        .get(
          Uri.https('oauth2.googleapis.com', '/tokeninfo', {
            'id_token': idToken,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final claims = jsonDecode(response.body) as Map<String, dynamic>;
    final clientId = Platform.environment['GOOGLE_CLIENT_ID'];
    if (clientId != null && clientId.isNotEmpty && claims['aud'] != clientId) {
      return null;
    }
    final email = claims['email'];
    if (email is! String) return null;
    return (email: email, emailVerified: claims['email_verified'].toString() == 'true');
  } catch (_) {
    return null;
  }
}
