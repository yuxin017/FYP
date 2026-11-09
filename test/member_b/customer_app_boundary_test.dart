import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visitor navigation cannot reach attraction management code', () {
    final lib = Directory('lib').absolute.uri;
    final pending = <Uri>[lib.resolve('visitor/visitor_main_page.dart')];
    final sources = <Uri, String>{};
    final directives = RegExp(
      r'''^\s*(?:import|export|part)\s+(.+?);''',
      multiLine: true,
      dotAll: true,
    );
    final quotedUri = RegExp(r'''['"]([^'"]+)['"]''');

    while (pending.isNotEmpty) {
      final uri = pending.removeLast().normalizePath();
      if (sources.containsKey(uri)) continue;
      final source = File.fromUri(uri).readAsStringSync();
      sources[uri] = source;
      for (final directive in directives.allMatches(source)) {
        for (final match in quotedUri.allMatches(directive.group(1)!)) {
          final target = Uri.parse(match.group(1)!);
          if (target.scheme == 'package') {
            if (target.pathSegments.first == 'collaborative_asg') {
              pending.add(lib.resolve(target.pathSegments.skip(1).join('/')));
            }
          } else if (!target.hasScheme) {
            pending.add(uri.resolveUri(target));
          }
        }
      }
    }

    expect(
      sources.keys,
      contains(lib.resolve('visitor/pages/queue_page.dart')),
      reason: 'The check must follow the actual customer navigation graph.',
    );
    expect(
      sources.keys.where((uri) => uri.toString().startsWith('${lib}admin/')),
      isEmpty,
      reason: 'Even an admin account must receive a customer-only application.',
    );
    final customerAttractions = sources.entries
        .where((entry) => entry.key.toString().startsWith('${lib}attractions/'))
        .map((entry) => entry.value)
        .join('\n');
    expect(customerAttractions, isNotEmpty);
    for (final operation in [
      'createAttraction',
      'updateAttraction',
      'deleteAttraction',
      'Manage attractions',
      'onManage',
    ]) {
      expect(
        customerAttractions,
        isNot(contains(operation)),
        reason: '$operation belongs to the separate website portal.',
      );
    }
  });
}
