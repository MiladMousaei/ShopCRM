import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows window starts maximized', () async {
    final source = await File('lib/main.dart').readAsString();

    expect(source, contains('await windowManager.maximize();'));
  });
}
