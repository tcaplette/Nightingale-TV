import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hard-coded user-facing text in screens fails here (design D12).
const _allowed = {'Nightingale TV', 'TV', 'OK', 'M3U'};

final _patterns = [
  RegExp(r'''\bText\(\s*r?(['"])([A-Z][^'"]*)\1'''),
  RegExp(r'''\b(?:label|title|message|hint|hints|action|tooltip|labelText|helperText|hintText|semanticLabel|allLabel|rowLabel|text)\s*:\s*r?(['"])([A-Z][^'"]*)\1'''),
];

List<String> scan(String root) {
  final found = <String>[];
  for (final file in Directory(root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    final lines = file.readAsLinesSync();
    for (final (i, line) in lines.indexed) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final p in _patterns) {
        for (final m in p.allMatches(line)) {
          if (!_allowed.contains(m[2])) found.add('${file.path}:${i + 1}: ${m[2]}');
        }
      }
    }
  }
  return found;
}

void main() {
  test('no hard-coded text in the screens', () {
    expect(scan('lib/ui'), isEmpty);
  });

  test('no hard-coded text in the web admin', () {
    expect(scan('lib/web_admin'), isEmpty);
  });
}
