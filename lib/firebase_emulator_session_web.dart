import 'dart:js_interop';

@JS('window.sessionStorage.removeItem')
external void _removeSessionItem(JSString key);

void resetFirebaseAuthEmulatorCache() {
  // Remove the SDK hint left by the previous local setup so it cannot
  // redirect this application away from its configured Firebase project.
  // Keep authentication persistence and all application data intact.
  try {
    _removeSessionItem('[DEFAULT]-firebaseEmulatorOrigin'.toJS);
  } catch (_) {
    // Storage can be unavailable in restricted browser contexts.
  }
}
