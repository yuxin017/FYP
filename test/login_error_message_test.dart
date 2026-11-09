import 'package:collaborative_asg/auth/login_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-in failures have useful messages instead of raw SDK text', () {
    expect(
      loginErrorMessage('invalid-credential'),
      'Incorrect email or password.',
    );
    expect(loginErrorMessage('wrong-password'), 'Incorrect email or password.');
    expect(
      loginErrorMessage('network-request-failed'),
      'Unable to connect. Check your connection and try again.',
    );
    expect(
      loginErrorMessage('invalid-api-key'),
      'Unable to sign in. Please try again.',
    );
    expect(
      loginErrorMessage('unknown'),
      'Unable to sign in. Please try again.',
    );
  });
}
