import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('SpeechRecognition')
external JSFunction? get speechRecognition;
@JS('webkitSpeechRecognition')
external JSFunction? get webkitSpeechRecognition;

Future<String> listenSpeech(String language) async {
  final constructor = speechRecognition ?? webkitSpeechRecognition;
  if (constructor == null) {
    throw StateError(
      'Voice input is unavailable in this browser. Please type your question.',
    );
  }
  final recognition = constructor.callAsConstructor<JSObject>(),
      result = Completer<String>();
  recognition.setProperty('lang'.toJS, language.toJS);
  recognition.setProperty('continuous'.toJS, false.toJS);
  recognition.setProperty('interimResults'.toJS, false.toJS);
  recognition.setProperty(
    'onresult'.toJS,
    ((JSObject event) {
      final results = event.getProperty<JSObject>('results'.toJS),
          first = results.getProperty<JSObject>('0'.toJS),
          alternative = first.getProperty<JSObject>('0'.toJS),
          transcript = alternative
              .getProperty<JSString>('transcript'.toJS)
              .toDart;
      if (!result.isCompleted) result.complete(transcript);
    }).toJS,
  );
  recognition.setProperty(
    'onerror'.toJS,
    ((JSObject event) {
      if (!result.isCompleted) {
        result.completeError(
          StateError(
            'Voice input could not start. Allow microphone access or type your question.',
          ),
        );
      }
    }).toJS,
  );
  recognition.setProperty(
    'onend'.toJS,
    ((JSObject event) {
      if (!result.isCompleted) result.complete('');
    }).toJS,
  );
  try {
    recognition.callMethod<JSAny?>('start'.toJS);
    return await result.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw StateError('No speech was detected. Please try again.'),
    );
  } finally {
    recognition.callMethod<JSAny?>('abort'.toJS);
  }
}
