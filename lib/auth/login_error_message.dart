String loginErrorMessage(String code) => switch (code) {
  'invalid-credential' ||
  'invalid-login-credentials' ||
  'wrong-password' ||
  'user-not-found' => 'Incorrect email or password.',
  'invalid-email' => 'Please enter a valid email address.',
  'too-many-requests' => 'Too many attempts. Please try again later.',
  'user-disabled' => 'This account has been disabled.',
  'network-request-failed' =>
    'Unable to connect. Check your connection and try again.',
  _ => 'Unable to sign in. Please try again.',
};
