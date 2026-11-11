import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApplicationApiException implements Exception {
  final String code, message;
  final Map<String, dynamic>? details;
  const ApplicationApiException(this.code, this.message, [this.details]);
  @override
  String toString() => message;
}

class ApplicationApi {
  final FirebaseAuth auth;
  ApplicationApi({FirebaseAuth? auth}) : auth = auth ?? FirebaseAuth.instance;
  Future<Map<String, dynamic>> post(
    String route, [
    Map<String, dynamic> data = const {},
  ]) => _post(route, data, authenticated: true);

  Future<Map<String, dynamic>> recovery(
    String action,
    Map<String, dynamic> data,
  ) {
    if (!['send', 'verify'].contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    return _post('/v1/recovery/$action', data, authenticated: false);
  }

  Future<Map<String, dynamic>> _post(
    String route,
    Map<String, dynamic> data, {
    required bool authenticated,
  }) async {
    final token = authenticated ? await auth.currentUser?.getIdToken() : null;
    if (authenticated && token == null) {
      throw const ApplicationApiException(
        'unauthenticated',
        'Please sign in again.',
      );
    }
    const origin = String.fromEnvironment(
      'ACCOUNT_SERVICE_URL',
      defaultValue: 'http://127.0.0.1:8787',
    );
    try {
      final response = await http
          .post(
            Uri.parse('$origin$route'),
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 60));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw ApplicationApiException(
          body['error'] as String? ?? 'unavailable',
          body['message'] as String? ?? 'Unable to complete this request.',
          body['details'] is Map
              ? Map<String, dynamic>.from(body['details'])
              : null,
        );
      }
      return body;
    } on ApplicationApiException {
      rethrow;
    } catch (_) {
      throw const ApplicationApiException(
        'unavailable',
        'Unable to connect. Your selected details have been kept. Please try again.',
      );
    }
  }
}
